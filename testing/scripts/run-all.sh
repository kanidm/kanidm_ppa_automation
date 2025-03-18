#!/bin/bash

set -e

# Configs defaults are defined here, but used much deeper in the call graph
export SSH_PORT="${SSH_PORT:-2222}"
export IDM_URI="${IDM_URI?}" # No reasonable default!
export IDM_GROUP="${IDM_GROUP:-posix_login}"
export TELNET_PORT="${TELNET_PORT:-4321}"
export MIRROR_PORT="${MIRROR_PORT:-31625}"
export CATEGORY="${CATEGORY:-stable}"
export USE_LIVE="${USE_LIVE:-false}"
export KANIDM_VERSION="${KANIDM_VERSION:-*}"  # * default picks latest
export IDM_USER="${IDM_USER:-$USER}"  # Only relevant if IDM_URI=local
export IDM_PORT="${IDM_PORT:-58915}"  # Only relevant if IDM_URI=local
export SSH_PUBLICKEY="${SSH_PUBLICKEY:-none}"  # Only relevant if IDM_URI=local
export ALLOW_UNSIGNED="${ALLOW_UNSIGNED:-true}"  # Only relevant if USE_LIVE=false

if [[ "$IDM_URI" == "local" ]] && [[ "$SSH_PUBLICKEY" == "none" ]]; then
  >&2 echo "SSH_PUBLICKEY must be set for IDM_URI=local"
  exit 1
fi

function cleanup(){
  set +e
  >&2 echo "Killing background processes..."
  rm -fr snapshot/*
  sleep 2  # Give a bit of time for any proper shutdown that may work
  [[ -f mirror.pid ]] && kill "$(cat mirror.pid)" ; ( rm mirror.pid 2>/dev/null )
  [[ -f qemu.pid ]]   && kill "$(cat qemu.pid)"   ; ( rm qemu.pid 2>/dev/null )
}


function prompt(){
  read -rp "Happy? ^C to stop full run, enter to continue to next target."
}

function run(){
	distro=$1
	scripts/launch-one.sh "$target" images/"${distro}"-*-"${arch}".*  || exit 1
	prompt
	sleep 2s  # Wait for qemu to release ports
}

if [[ ! -f test_payload.sh ]]; then
  test_root="$(readlink -f "$(dirname "$0")"/..)"
  >&2 echo "This script expects to be run from $test_root"
  exit 1
fi

scripts/get-images.sh

### Launch the repo snapshot in the background
# Assumes you've downloaded kanidm_ppa_snapshot.zip from a signed fork branch.

if [[ "$USE_LIVE" == "false" ]]; then
  >&2 echo "Launching mirror snapshot..."
  if [[ ! -f kanidm_ppa_snapshot.zip ]]; then
    >&2 echo "kanidm_ppa_snapshot.zip is missing in $PWD, we need it for packages. Or set USE_LIVE=true"
    exit 1
  fi
  scripts/run-mirror.sh kanidm_ppa_snapshot.zip &
  sleep 2s  # A bit of time for the unzip before we try to use the mirror
fi

trap cleanup EXIT

### Sequencing of permutations. The defaults only test current stable on current native arch
# You could just enable aarch64 manually below, but better off running on a pi5 natively!

target="$(uname -m)"
arch="$(dpkg --print-architecture)"

#target=aarch64
#arch=arm64

targets=(debian-12 noble)
# nightly is only available for latest LTS
[[ "$CATEGORY" != "nightly" ]] && targets+=(jammy)

for distro in "${targets[@]}"; do
  >&2 echo "Testing target: ${distro} w/ IDM_URI=${IDM_URI}, ${CATEGORY} @ USE_LIVE=${USE_LIVE}"
  run "$distro"
done
>&2 echo "Done with all targets"

set +e  # Allow cleanup to fail
cleanup || exit 0
