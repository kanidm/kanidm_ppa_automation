#!/bin/bash

set -eu

# These should come over SSH and we can assume they have values by this point
MIRROR_PORT="${MIRROR_PORT?}"
KANIDM_VERSION="${KANIDM_VERSION?}"
CATEGORY="${CATEGORY?}"
USE_LIVE="${USE_LIVE?}"
USE_DEBDIR="${USE_DEBDIR?}"
IDM_URI="${IDM_URI?}"
IDM_PORT="${IDM_PORT?}"
IDM_USER="${IDM_USER?}"
SSH_PUBLICKEY="${SSH_PUBLICKEY?}"
PRETEND_TARGET="${PRETEND_TARGET?}"

# Use a bit of color so it's easier to spot payload log vs. target output
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[32m"
ENDCOLOR="\e[0m"
function log(){
  color="$1"
  shift
  # Logging is echoed to stderr but also written to the target journald for timing related investigation.
  echo -e "${color}${*}${ENDCOLOR}" | tee /dev/stderr | systemd-cat -t test-payload
}

function debug(){
  set +x
	log "$RED" "Something went wrong with ${KANIDM_VERSION}/${CATEGORY} on $PRETTY_NAME, pausing for debug, to connect:"
	log "$ENDCOLOR" "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@localhost -p 2222 -i ssh_ed25519"
	log "$GREEN" "This may be helpful to investigate:"
	log "$ENDCOLOR" journalctl -o short-iso-precise -e
	sleep infinity
}

# Run things within DynamicUser without messing up permissions
function dyn_run(){
  systemd-run --pty  \
    --property=DynamicUser=yes --property=User=kanidmd_dyn --property=Group=kanidmd --property=StateDirectory=kanidmd \
    "$@"
}

# A much quicker & repeatable targeted apt update, we only care about our mirror
function apt_update(){
  apt-get update -y \
    -o Dir::Etc::sourcelist="sources.list.d/kanidm_ppa.list" \
    -o Dir::Etc::sourceparts="-" \
    -o APT::Get::List-Cleanup="0"
}

source /etc/os-release
log "$GREEN" "Running test payload on $(uname -m) for ${PRETTY_NAME}"
[[ "$PRETEND_TARGET" != "false" ]] && log "RED" ".. But we're pretending to be: '${PRETEND_TARGET}'"

# Sometimes qemu isn't so great at networking, and it's real confusing if we don't explicitly fail on it
test_uri="$IDM_URI"
[[ "$IDM_URI" == "local" ]] && test_uri="https://github.com"
log "$GREEN" "Testing network connectivity to ${test_uri} ..."
curl -s "$test_uri" > /dev/null || debug

# Make apt shut up about various things to see relevant output better
export DEBIAN_FRONTEND=noninteractive
export LC_CTYPE=C.UTF-8
export LC_ALL=C.UTF-8

# Cloud images come with an empty cache and we need dependencies
log "$GREEN" "Refreshing apt cache..."
apt update || debug

if [[ "$PRETEND_TARGET" == "false" ]]; then
  TARGET="$VERSION_CODENAME"
else
  TARGET="$PRETEND_TARGET"
fi

if [[ "$USE_LIVE" == "true" ]]; then
  log "$GREEN" "Configuring live mirror..."
  set -x
  curl -s "https://kanidm.github.io/kanidm_ppa/kanidm_ppa.asc" > /etc/apt/trusted.gpg.d/kanidm_ppa.asc || debug
  curl -s "https://kanidm.github.io/kanidm_ppa/kanidm_ppa.list" \
    | grep "$TARGET" \
    | grep "$CATEGORY" \
    > /etc/apt/sources.list.d/kanidm_ppa.list || debug
  set +x
  cat /etc/apt/sources.list.d/kanidm_ppa.list
  apt_update || debug
elif [[ "$USE_DEBDIR" != "false" ]]; then
  log "$GREEN" "USE_DEBDIR is enabled, skipping repo config and instead installing from:$ENDCOLOR $(ls ./*.deb)"
else
  # Default is to assume a templated localhost mirror file was pushed in and use that.
  if [[ -f kanidm_ppa.asc ]]; then
    mv kanidm_ppa.asc /etc/apt/trusted.gpg.d/
  else
    log "$YELLOW" "No signing key, configuring mirror to be unsigned.."
    sed -e 's/\[.*\]/[trusted=yes]/' -i kanidm_ppa.list
  fi
  ls -la /etc/apt/sources.list.d/ || debug
  sed "s/%MIRROR_PORT%/${MIRROR_PORT}/;s/%VERSION_CODENAME%/${TARGET}/;s/%CATEGORY%/${CATEGORY}/" kanidm_ppa.list > /etc/apt/sources.list.d/kanidm_ppa.list || debug
  log "$GREEN" "Using snapshot mirror:"
  cat /etc/apt/sources.list.d/kanidm_ppa.list
  apt_update || debug
fi

LOCAL_IDM="false"
if [[ "$IDM_URI" == "local" ]]; then
  LOCAL_IDM="true"
  if [[ "$USE_DEBDIR" != "false" ]]; then
    # apt-get allows installing debs and helps resolve dependencies
    # BUT they need to look like paths and not package names.
    mapfile -t kanidmd_debs <<< "$(readlink -f ./kanidmd_*.deb ./kanidm_*.deb)"
    log "$GREEN" "Installing kanidmd & kanidm packages from provided debs"
    set -x
    apt-get install -y jq "${kanidmd_debs[@]}" || debug
    set +x
  else
    # Default assumes mirror
    version="$(apt-cache show "kanidm-unixd=${KANIDM_VERSION}*" | sed -nE 's/^Version: (.*)/\1/p')"
    log "$GREEN" "Installing kanidmd & kanidm packages for version: ${version}"
    set -x
    apt-get install -y jq \
      "kanidmd=${version}" \
      "kanidm=${version}" || debug
    set +x
  fi
  log "$GREEN" "Configuring kanidm cli..."
  mkdir -p /etc/kanidm
  sed -e "s_^uri =_uri = _" /usr/share/kanidm/config > /etc/kanidm/config
  log "$GREEN" "Configuring kanidmd..."
  IDM_URI="https://localhost:${IDM_PORT}"
  sed "/bindaddress/s/8443/${IDM_PORT}/" -i /etc/kanidmd/server.toml
  sed "s/#domain =.*/domain = \"localhost\"/" -i /etc/kanidmd/server.toml
  sed "s_#origin =.*_origin = \"${IDM_URI}\"_" -i /etc/kanidmd/server.toml
  
  log "$GREEN" "Generating certs for kanidmd..."
  # Work around issue #3505, the DB must exist before cert-generate
  dyn_run touch /var/lib/private/kanidmd/kanidm.db
  kanidmd cert-generate || debug

  log "$GREEN" "Starting kanidmd..."
  systemctl start kanidmd.service || debug
  sleep 5s
  
  log "$GREEN" "Seeding kanidmd for posix login..."
  password="$(kanidmd recover-account idm_admin -o json | grep password | jq .password | tr -d \")"
  # kanidm the cli tool doesn't ship with a default config, and unixd does.
  # So instead of poking at that whole mess, we just use a temporary config.
  mkdir -p /etc/kanidm
  printf 'uri = "%s"\nverify_ca = false\n' "$IDM_URI" > /etc/kanidm/config
  kanidm login -H "$IDM_URI" -D idm_admin --password "$password" || debug
  kanidm person create -H "$IDM_URI" -D idm_admin "$IDM_USER" "$IDM_USER" || debug
  kanidm group create -H "$IDM_URI" -D idm_admin "$IDM_GROUP" || debug
  kanidm group add-members -H "$IDM_URI" -D idm_admin "$IDM_GROUP" "$IDM_USER" || debug
  kanidm person posix set -H "$IDM_URI" -D idm_admin "$IDM_USER" || debug
  kanidm group posix set -H "$IDM_URI" -D idm_admin "$IDM_GROUP" || debug
  kanidm person ssh add-publickey -H "$IDM_URI" -D idm_admin "$IDM_USER" testkey "$SSH_PUBLICKEY" || debug
  rm -r /etc/kanidm  # Terminate the temporary config so the proper is generated later by dpkg
fi

log "$GREEN" "Pre-emptively enabling debug logging for kanidm services"
for service in kanidm-unixd kanidm-unixd-tasks; do
  mkdir -p "/etc/systemd/system/${service}.service.d"
  cat << EOF > "/etc/systemd/system/${service}.service.d/env.conf"
[Service]
# Needed for =< 1.5
Environment="KANIDM_DEBUG=true"
# Works for >= 1.6
Environment="RUST_LOG=kanidm=debug"
EOF
done

log "$GREEN" "Installing debug tools in-case you need them"
apt-get install -y strace pamtester

if [[ "$USE_DEBDIR" != "false" ]]; then
  # apt-get allows installing debs and helps resolve dependencies
  # BUT they need to look like paths and not package names.
  mapfile -t kanidmd_debs <<< "$(readlink -f ./kanidmd_*.deb ./kanidm_*.deb)"
  mapfile -t unixd_debs <<< "$(readlink -f ./kanidm_*.deb ./kanidm-unixd_*.deb ./lib*-kanidm_*.deb)"
  log "$GREEN" "Installing kanidm-unixd & kanidm packages from provided debs: ${unixd_debs[*]}"
  set -x
  apt-get install -y "${unixd_debs[@]}" || debug
  set +x
else
  version="$(apt-cache show "kanidm-unixd=${KANIDM_VERSION}*" | sed -nE 's/^Version: (.*)/\1/p')"
  log "$GREEN" "Installing kanidm-unixd & kanidm packages for version: ${version}"
  apt-get install -y zsh \
    "kanidm-unixd=${version}" \
    "kanidm=${version}" \
    "libpam-kanidm=${version}" \
    "libnss-kanidm=${version}" \
    || debug
fi

log "$GREEN" "Configuring kanidm-unixd..."
if [[ "$LOCAL_IDM" == "true" ]]; then
  log "$GREEN" "Using local kanidmd, disabling verify_ca"
  sed -e '/^verify_ca/s/true/false/' -i /etc/kanidm/config
fi
# Set Kanidm level uri
sed "s_# *uri.*_uri = \"${IDM_URI}\"_" -i /etc/kanidm/config
# Enable kanidm based posix login
sed "/^# *\[kanidm\]/s/[# ]//g" -i /etc/kanidm/unixd
sed "s@# *pam_allowed_login_groups.*@pam_allowed_login_groups = \[\"${IDM_GROUP}\"\]@" -i /etc/kanidm/unixd


log "$GREEN" "Restarting unixd"
systemctl restart kanidm-unixd.service || debug

log "$GREEN" "Configuring NSS"
sed -E 's/(passwd|group): (.*)/\1: \2 kanidm/' -i /etc/nsswitch.conf

log "$GREEN" "Configuring sshd"

cat << EOT >> /etc/ssh/sshd_config
PubkeyAuthentication yes
UsePAM yes
AuthorizedKeysCommand /usr/sbin/kanidm_ssh_authorizedkeys %u
AuthorizedKeysCommandUser nobody
LogLevel DEBUG1
EOT
systemctl restart ssh.service || debug

log "$GREEN" "Running basic testing of results:"
set -x
# This will work as long as kanidmd will respond
if [[ -x /usr/bin/kanidm_ssh_authorizedkeys_direct ]]; then
  [[ -n $(/usr/bin/kanidm_ssh_authorizedkeys_direct --name anonymous "$IDM_USER") ]] || debug
fi
# This requires unixd to be configured for kanidm use
[[ -n $(/usr/sbin/kanidm_ssh_authorizedkeys "$IDM_USER") ]] || debug
# This also requires NSS to be configured for kanidm use
getent passwd "$IDM_USER" || debug
# This also requires PAM to be functional
pamtester -v login "$IDM_USER" open_session || debug
set +x


log "$GREEN" "Go test ssh login! Do a ^C here when you're done"
log "$ENDCOLOR" "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null localhost -p 2222"
log "$GREEN" "Or for direct ssh skipping unixd:"
log "$ENDCOLOR" "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@localhost -p 2222 -i ssh_ed25519"
log "$GREEN" "Now following kanidm-unixd, kanidm-unixd-tasks & ssh logs:"
# We filter the logging slightly to drop multi-screen long event dumps 
(journalctl -f --lines 50 -o short-iso-precise -u kanidm-unixd.service -u kanidm-unixd-tasks.service -u ssh.service | sed --unbuffered -E 's/(DebouncedEvent|EtcDb) .*/\[.. debugdump omitted for brevity ..\]/') || debug
