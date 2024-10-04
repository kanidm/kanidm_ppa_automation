#!/bin/bash

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <target>"
    if [ -d ./crossbuild ]; then
        echo "Valid targets:"
        find crossbuild/ -maxdepth 1 -mindepth 1 -type d | awk -F'/' '{print $NF}' | sort
    else
        echo "This script must be run from the repo root (crossbuild dir missing)."
    fi
    exit 1
fi

if [ ! -d "crossbuild/$1" ]; then
    echo "Could not find target at: crossbuild/$1"
    exit 1
fi

# Find the target rust architecture
TRIPLET=$(echo $1 | cut -d \- -f 3-)
echo "Crossbuilding for: $TRIPLET"
rustup target add "$TRIPLET"

CROSS_CONFIG="crossbuild/${1}/Cross.toml" \
    cross build --target "$TRIPLET" \
        --bin kanidm_unixd \
        --bin kanidm_unixd_tasks \
        --bin kanidm_ssh_authorizedkeys \
        --bin kanidm-unix \
        --release
CROSS_CONFIG="crossbuild/${1}/Cross.toml" \
    cross build --target "$TRIPLET" \
        -p pam_kanidm \
        -p nss_kanidm \
        --release

TRIPLET=$(echo $1 | cut -d \- -f 3-)

echo "Build artefacts for ${TRIPLET}:"
find "./target/${TRIPLET}/release/" -maxdepth 1 \
    -type f -not -name '*.d' \
    -name '*kanidm*'
