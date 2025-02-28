#!/bin/bash

# If you're a human, don't run this script on your daily machine, instead follow the instructions at: 
# https://kanidm.github.io/kanidm/stable/packaging/debian_ubuntu_packaging.html
# This script is actively hostile against you human if used outside those instructions, you have been warned. :3
# Technically it's no longer quite as hostile since dropping multiarch crossbuild, but we reserve the right for it to be, so the guarding is still here.

if [[ -z "$CI" ]]; then
    >&2 echo "Error, this script is only to be run from CI."
    exit 1
fi

set -eu

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

2>&1 echo "Installing build dependencies from APT for ${PRETTY_NAME}"
apt-get update || cat /etc/apt/sources.list.d/ubuntu.sources
apt-get install -y \
    curl \
    build-essential pkg-config llvm clang \
    libssl-dev libpam0g-dev libudev-dev \
    "$ssl"
