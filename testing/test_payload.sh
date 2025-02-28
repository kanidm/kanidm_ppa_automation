#!/bin/bash

# This script is completely cut off from any upstream env and needs explicit args
IDM_URI="${1?}"
IDM_GROUP="${2?}"
MIRROR_PORT="${3?}"
KANIDM_VERSION="${4?}"
CATEGORY="${5?}"
USE_LIVE="${6?}"

set -eu

# Use a bit of color so it's easier to spot payload log vs. target output
RED="\e[31m"
ENDCOLOR="\e[0m"
function log(){
  >&2 echo -e "${RED}${1}${ENDCOLOR}"
}

function debug(){
	log "Something went wrong, pausing for debug, to connect:"
	log "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@localhost -p 2222 -i ssh_ed25519"
	sleep infinity
}

source /etc/os-release
log "Running test payload on $(uname -m) for ${PRETTY_NAME}"

# Make apt shut up about various things to see relevant output better
export DEBIAN_FRONTEND=noninteractive
export LC_CTYPE=C.UTF-8
export LC_ALL=C.UTF-8

mv kanidm_ppa.asc /etc/apt/trusted.gpg.d/
if [[ "$USE_LIVE" == "true" ]]; then
  curl -s "http://10.0.2.2:${MIRROR_PORT}/kanidm_ppa.list" \
    | grep $( ( . /etc/os-release && echo $VERSION_CODENAME) ) \
    | grep "$CATEGORY" \
    > /etc/apt/sources.list.d/kanidm_ppa.list
  log "Using LIVE PPA instead of local snapshot mirror:"
  cat /etc/apt/sources.list.d/kanidm_ppa.list
else
  sed "s/%MIRROR_PORT%/${MIRROR_PORT}/;s/%VERSION_CODENAME%/${VERSION_CODENAME}/;s/%CATEGORY%/${CATEGORY}/" kanidm_ppa.list > /etc/apt/sources.list.d/kanidm_ppa.list
  log "Using snapshot mirror:"
  cat /etc/apt/sources.list.d/kanidm_ppa.list
fi

# Sometimes qemu isn't so great at networking, and it's real confusing if we don't explicitly fail on it
log "Testing network connectivity to ${IDM_URI} ..."
curl -s "$IDM_URI" > /dev/null || debug

apt update || debug

# Resolve the given version spec to an exact one
version="$(apt-cache show "kanidm-unixd=${KANIDM_VERSION}*" | sed -nE 's/^Version: (.*)/\1/p')"
log "Installing Kanidm packages for version: ${version}"
apt install -y zsh \
  "kanidm-unixd=${version}" \
  "kanidm=${version}" \
  "libpam-kanidm=${version}" \
  "libnss-kanidm=${version}" \
  || debug

log "Configuring kanidm-unixd"
sed "s_# *uri.*_uri = \"${IDM_URI}\"_" -i /etc/kanidm/config
sed "s@# *pam_allowed_login_groups.*@pam_allowed_login_groups = \[\"${IDM_GROUP}\"\]@" -i /etc/kanidm/unixd

log "Enabling debug logging for kanidm-unixd"
mkdir -p /etc/systemd/system/kanidm-unixd.service.d
cat << EOF > /etc/systemd/system/kanidm-unixd.service.d/env.conf
[Service]
Environment="KANIDM_DEBUG=true"
EOF
systemctl daemon-reload

log "Restarting unixd"
systemctl restart kanidm-unixd.service || debug

log "Configuring NSS"
sed -E 's/(passwd|group): (.*)/\1: \2 kanidm/' -i /etc/nsswitch.conf

log "Configuring sshd"

cat << EOT >> /etc/ssh/sshd_config
PubkeyAuthentication yes
UsePAM yes
AuthorizedKeysCommand /usr/sbin/kanidm_ssh_authorizedkeys %u
AuthorizedKeysCommandUser nobody
LogLevel DEBUG1
EOT
systemctl restart ssh.service || debug

log "Go test ssh login! Do a ^C here when you're done"
log "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null localhost -p 2222"
log "Or for direct ssh skipping unixd:"
log "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@localhost -p 2222 -i ssh_ed25519"
log "Now following kanidm-unixd & ssh logs:"
journalctl -f -u kanidm-unixd.service -u ssh.service
