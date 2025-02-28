#!/bin/bash

set -e

# Configs specific to your environment
export SSH_PORT="${SSH_PORT:-2222}" # Any free port will do
export IDM_URI="${IDM_URI?}" # No reasonable default!
export IDM_GROUP="${IDM_GROUP:-posix_login}"
export TELNET_PORT="${TELNET_PORT:-4321}"
export MIRROR_PORT="${MIRROR_PORT:-31625}"

function cleanup(){
  set +e
  >&2 echo "Cleaning up the snapshot mirror..."
  rm -fr snapshot/*
  >&2 echo "Killing background processes..."
  sleep 2  # Give a bit of time for any proper shutdown that may work
  [[ -f mirror.pid ]] && kill "$(cat mirror.pid)" ; rm mirror.pid
  [[ -f qemu.pid ]]   && kill "$(cat qemu.pid)"   ; rm qemu.pid
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
if [[ ! -f kanidm_ppa_snapshot.zip ]]; then
  >&2 echo "kanidm_ppa_snapshot.zip is missing in $PWD, we need it for testing"
  exit 1
fi

>&2 echo "Launching mirror snapshot"
scripts/run-mirror.sh kanidm_ppa_snapshot.zip &
trap cleanup EXIT
sleep 2s  # A bit of time for the unzip before we try to use the mirror

### Sequencing of permutations. The defaults only test current stable on current native arch
# You could just enable aarch64 manually below, but better off running on a pi5 natively!

target="$(uname -m)"
arch="$(dpkg --print-architecture)"

#target=aarch64
#arch=arm64

for distro in debian-12 jammy noble; do
  run "$distro"
done

set +e  # Allow cleanup kills to fail
cleanup
