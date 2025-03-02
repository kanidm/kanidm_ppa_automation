#!/bin/bash

set -e

BASEDIR="$(readlink -f $(dirname $0)/..)"

if [ ! -f "Cargo.toml" ]; then
    >&2 echo "Your current working directory doesn't look like we'll find the sources to build. This script must be run from from a checked out copy of the kanidm/kanidm project root."
    exit 1
fi

# Expected target format: debian-12-aarch64-unknown-linux-gnu
target=${1?}

. /etc/os-release

echo "Building for: ${target} on ${PRETTY_NAME}"
rustup target add "$target"

export KANIDM_BUILD_PROFILE="release_linux"
export RUSTFLAGS="-Clinker=clang -Clink-arg=-fuse-ld=/usr/local/bin/mold"

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
