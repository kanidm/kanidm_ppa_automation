#!/bin/bash

# If you're a human, don't run this script on your daily machine, instead follow the instructions at: 
# https://kanidm.github.io/kanidm/stable/packaging/debian_ubuntu_packaging.html
# This script is actively hostile against you human if used outside those instructions, you have been warned. :3

if [[ -z "$CI" ]]; then
    >&2 echo "Error, this script is only to be run from CI."
    exit 1
fi

set -eu

if [[ "$UID" != 0 ]]; then
    >&2 echo "Error, this script must be run as root."
    exit 1
fi

DEB_OS="${1?}" # Expecting "debian" or "ubuntu"
DEB_ARCH="${2?}" # Expecting "amd64" or "arm64" etc

# Ubuntu does not do multiarch correctly, does not document this at all etc,
# so we just need a bunch of dirty hacks to do it Their Way. GitHub Actions makes this even worse.
# Technically we don't need to do this with a native build, but it also doesn't hurt.
if [[ "$DEB_OS" == "ubuntu" ]]; then
    2>&1 echo "Patching Ubuntu apt sources for multiarch"
    # Default entries do not pin an arch, fix that
    # GHA since 24.04 keeps them in a separate file
    sed -E 's/^deb (http|mirror)/deb [arch=amd64] \1/' -i /etc/apt/sources.list /etc/apt/sources.list.d/ubuntu.sources
    # arm64 is on a completely different mirror structure, add that pinned to arm64
    echo 'deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports/ jammy main restricted' > /etc/apt/sources.list.d/arm64.list
    echo 'deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports/ jammy-updates main restricted' >> /etc/apt/sources.list.d/arm64.list
fi

# From here on normal Debian multiarch logic applies
2>&1 echo "Enabling multiarch"
dpkg --add-architecture $DEB_ARCH
apt-get update || cat /etc/apt/sources.list.d/ubuntu.sources
apt-get install -y \
    libssl3:$DEB_ARCH \
    libpam0g:$DEB_ARCH \
    libudev1:$DEB_ARCH
