#!/bin/bash

set -e

# The target triplet must be given as an arg, for example: x86_64-unknown-linux-gnu
if [ -z "$1" ]; then
    >&2 echo "Missing target triplet as argument, for example: ${0} x86_64-unknown-linux-gnu"
    exit 1
fi
target="$1"

if [ ! -f "Cargo.toml" ]; then
    >&2 echo "Your current working directory doesn't look like we'll find the sources to build. This script must be run from from a checked out copy of the kanidm/kanidm project root."
    exit 1
fi

# In CI we set up a rust env already by this point, but doesn't hurt to make sure it's up to date.
>&2 echo "Updating Rust toolchain..."
rustup toolchain install stable

. /etc/os-release

# Where available, we use a dedicated Debian build profile
if [[ -f libs/profiles/release_debian.toml ]]; then
    export KANIDM_BUILD_PROFILE="release_debian"
else
    export KANIDM_BUILD_PROFILE="release_linux"
fi


echo "Building for: ${target}  with profile ${KANIDM_BUILD_PROFILE} on ${PRETTY_NAME}"

cargo build --target "$target" \
  --bin kanidm_unixd \
  --bin kanidm_unixd_tasks \
  --bin kanidm_ssh_authorizedkeys \
  --bin kanidm-unix \
  --bin kanidm \
  --release
cargo build --target "$target" \
  -p pam_kanidm \
  -p nss_kanidm \
  --release

echo "Build artefacts for ${target} on ${PRETTY_NAME}:"
find "./target/${target}/release/" -maxdepth 1 \
        -type f -not -name '*.d' -not -name '*.rlib' \
    -name '*kanidm*'

echo "All current artefacts across targets:"
find ./target/*/release/ -maxdepth 1 \
    -type f -not -name '*.d' -not -name '*.rlib' \
    -name '*kanidm*'
