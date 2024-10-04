#!/bin/bash

set -e

BASEDIR="$(dirname $0)/.."

if [ -z "$1" ]; then
    echo "Usage: $0 <target>"
    if [ -d "${BASEDIR}/crossbuild" ]; then
        echo "Valid targets:"
        find "${BASEDIR}/crossbuild/" -maxdepth 1 -mindepth 1 -type d | awk -F'/' '{print $NF}' | sort
    else
	echo "Missing crossbuild configs, cannot proceed."
    fi
    exit 1
fi

# Iterate over given targets.
targets=("$@")
for target in "${targets[@]}"; do
	if [ ! -d "${BASEDIR}/crossbuild/$1" ]; then
	    echo "Could not find target at: ${BASEDIR}/crossbuild/$1"
	    exit 1
	fi

	# Find the target rust architecture
	OS=$(echo $1 | cut -d \- -f 1-2)
	TRIPLET=$(echo $1 | cut -d \- -f 3-)
	echo "Crossbuilding for: $TRIPLET"
	rustup target add "$TRIPLET"

	export CROSS_CONFIG="${BASEDIR}/crossbuild/${OS}.toml"

	cross build --target "$TRIPLET" \
		--bin kanidm_unixd \
		--bin kanidm_unixd_tasks \
		--bin kanidm_ssh_authorizedkeys \
		--bin kanidm-unix \
		--release
	cross build --target "$TRIPLET" \
		-p pam_kanidm \
		-p nss_kanidm \
		--release

	echo "Build artefacts for ${TRIPLET}:"
	find "./target/${TRIPLET}/release/" -maxdepth 1 \
    	    -type f -not -name '*.d' -not -name '*.rlib' \
	    -name '*kanidm*'
done
echo "All current artefacts across targets:"
find ./target/*/release/ -maxdepth 1 \
    -type f -not -name '*.d' -not -name '*.rlib' \
    -name '*kanidm*'
