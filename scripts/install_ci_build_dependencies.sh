#!/bin/bash

# If you're a human, don't run this script on your daily machine, instead follow the instructions at: 
# https://kanidm.github.io/kanidm/stable/packaging/debian_ubuntu_packaging.html
# This script is actively hostile against you human if used outside those instructions, you have been warned. :3
# Technically it's no longer quite as hostile since dropping multiarch crossbuild, but we reserve the right for it to be, so the guarding is still here.

set -eu

if [[ -z "${CI:-}" ]]; then
    >&2 echo "Error, this script should be run in a specific way, go re-read the instructions: https://kanidm.github.io/kanidm/stable/packaging/debian_ubuntu_packaging.html"
    exit 1
fi


if [[ "$UID" != 0 ]]; then
    >&2 echo "Error, this script must be run as root."
    exit 1
fi

. /etc/os-release

case "$ID" in
  debian)
    ssl="libssl3"
    ;;
  ubuntu)
    case "$VERSION_ID" in
      22.04)
        ssl="libssl3"
        ;;
      *)
        # Thanks Ubuntu, I hate it
        ssl="libssl3t64"
        ;;
    esac
    ;;
esac

if [[ -n "${RUSTFLAGS:-}" ]]; then
  # Assumed RUSTFLAGS is set to some specific linker and it's already installed
  linker=""
else
  >&2 echo "RUSTFLAGS is not set, falling back to lld for linking!"
  linker="lld"
fi

>&2 echo "Installing build dependencies from APT for ${PRETTY_NAME}"
apt-get update || cat /etc/apt/sources.list.d/ubuntu.sources
apt-get install -y \
    curl wget \
    build-essential pkg-config llvm clang \
    libssl-dev libpam0g-dev libudev-dev \
    "$ssl" "$linker"
