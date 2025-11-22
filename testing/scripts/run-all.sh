#!/bin/bash

set -e

# Configs defaults are defined here, but some used much deeper in the call graph
export SSH_PORT="${SSH_PORT:-2222}"
export IDM_URI="${IDM_URI?}" # No reasonable default!
export IDM_GROUP="${IDM_GROUP:-posix_login}"
export TELNET_PORT="${TELNET_PORT:-4321}"
export MIRROR_PORT="${MIRROR_PORT:-31625}"
export CATEGORY="${CATEGORY:-stable}"
export USE_LIVE="${USE_LIVE:-false}"
export USE_DEBDIR="${USE_DEBDIR:-false}"  # If not false, expected to be a directory
export KANIDM_VERSION="${KANIDM_VERSION:-*}"  # * default picks latest
export KANIDM_UPGRADE="${KANIDM_UPGRADE:-false}"  # To test upgrades: set KANIDM_VERSION to an old version and this to true
export IDM_USER="${IDM_USER:-$USER}"
export IDM_PORT="${IDM_PORT:-58915}"  # Only relevant if IDM_URI=local
export SSH_PUBLICKEY="${SSH_PUBLICKEY:-none}"  # Only relevant if IDM_URI=local
export ALLOW_UNSIGNED="${ALLOW_UNSIGNED:-true}"  # Only relevant if USE_LIVE=false
export OSARCH="${OSARCH:-$(dpkg --print-architecture)}"  # cross-arch is in no way guaranteed to work
export CPUARCH="${CPUARCH:-$(uname -m)}"  # But if you insist, override both
TEST_TARGETS="${TEST_TARGETS:-}"  # Single string space separated which targets to run. Default runs all
export PRETEND_TARGET="${PRETEND_TARGET:-false}"  # Force all TEST_TARGETS to install packages from this target
SUCCESS_WAIT="${SUCCESS_WAIT:-true}"  # Ask for confirmation before continuing to the next test after a success
TEST_ROOT="$(readlink -f "$(dirname "$0")"/..)"

if [[ "$IDM_URI" == "local" ]] && [[ "$SSH_PUBLICKEY" == "none" ]]; then
  >&2 echo "SSH_PUBLICKEY must be set for IDM_URI=local"
  exit 1
fi

if [[ "$(readlink -f "$PWD")" != "$TEST_ROOT" ]]; then
  >&2 echo "Adjusting rundir to ${TEST_ROOT}"
  cd "$TEST_ROOT"
fi

# shellcheck source=../lib/log.sh
source lib/log.sh
# shellcheck source=../lib/targets.sh
source lib/targets.sh

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
	distro="$1"
	scripts/launch-one.sh "$CPUARCH" "images/$(basename "${!distro}")"  || exit 1
	[[ "$SUCCESS_WAIT" == "true" ]] && prompt
	sleep 2s  # Wait for qemu to release ports
}


function get_images(){
  targets=("$@")
  mkdir -p images

  # Expand targets to images
  images=()
  for target in "${targets[@]}"; do
          images+=("${!target}")
  done

  # Download & prep all requested target images
  log "$GREEN" "Preloading any missing target images"
  for url in "${images[@]}"; do
          file="$(basename "$url")"
          if [[ ! -f "images/${file}" ]]; then
                  wget "$url" -O "images/${file}"
                  log "$GREEN" "Resizing $file so the dpkg operations & debug binaries will fit"
                  # The bump is quite big as the worst case scenario has ~100MiB empty after
                  # debug deb installs even with this size. This does not increase the on-disk size.
                  qemu-img resize "images/${file}" +1.5G  
          fi
  done
}

### Main

# If we already have a target list, use it as-is
if [[ -n "$TEST_TARGETS" ]]; then
  IFS=" " read -r -a targets <<< "$TEST_TARGETS"
else
  # Base set of targets: Latest LTS releases
  targets=(trixie noble)
  # Additional targets won't work for nightly
  if [[ "$CATEGORY" != "nightly" ]]; then
    # Previous still supported LTS
    targets+=(bookworm jammy)
    # Interim releases
    targets+=(plucky)
  fi
fi
log "$GREEN" "Full set of test targets:${ENDCOLOR} ${targets[*]}"

### Launch the repo snapshot in the background
# Assumes you've downloaded kanidm_ppa_snapshot.zip from a signed fork branch.

if [[ "$USE_LIVE" == "false" && "$USE_DEBDIR" == "false" ]]; then
  log "$GREEN" "Launching mirror snapshot..."
  if [[ ! -f kanidm_ppa_snapshot.zip ]]; then
    log "$RED" "kanidm_ppa_snapshot.zip is missing in $PWD, we need it for packages."
    log "$RED" "Alternatively set USE_LIVE=true, or provide a USE_DEBDIR with deb packages."
    exit 1
  fi
  scripts/run-mirror.sh kanidm_ppa_snapshot.zip &
  sleep 2s  # A bit of time for the unzip before we try to use the mirror
fi

modestring="mirror snapshot, version: ${KANIDM_VERSION}/${CATEGORY}"
[[ "$KANIDM_UPGRADE" != "false" ]] && modestring+=", upgrading to latest"
[[ "$USE_DEBDIR" != "false" ]] && modestring="debs from ${USE_DEBDIR}"
[[ "$USE_LIVE" == "true" ]] && modestring="live mirror, version: ${KANIDM_VERSION}/${CATEGORY}"

trap cleanup EXIT

# Ensure the right VM images are present
get_images "${targets[@]}"

for target in "${targets[@]}"; do
  log "$GREEN" "Testing target: ${ENDCOLOR} ${target} ${CPUARCH}/${OSARCH} w/ IDM_URI=${IDM_URI}, installing from: ${modestring}"
  run "$target"
done
log "$GREEN" "Done with all targets"

set +e  # Allow cleanup to fail
cleanup || exit 0
exit 0
