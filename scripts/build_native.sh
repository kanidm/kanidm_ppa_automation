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

# In CI we set up a rust env already by this point, BUT rust-toolchain.toml is cruel and will override that version to `stable`
export RUSTUP_TOOLCHAIN="$(awk -F \" '/^rust-version/ {print $2}' Cargo.toml)"
# BUT, cargo-version is also not reliably up to date, so set a minimum known version needed:
MIN_RUST_VERSION="1.85" # Required to meet `edition2024` for haproxy-protocol v0.0.1
printf '%s\n%s\n' "$MIN_RUST_VERSION" "$RUSTUP_TOOLCHAIN" \
    | sort --check=quiet --version-sort \
    || export RUSTUP_TOOLCHAIN="$MIN_RUST_VERSION"
>&2 echo "Checking Rust toolchain version, expecting ${RUSTUP_TOOLCHAIN}:"
rustup show active-toolchain

# Where available, we use a dedicated Debian build profile
if [[ -f libs/profiles/release_debian.toml ]]; then
    export KANIDM_BUILD_PROFILE="release_debian"
else
    export KANIDM_BUILD_PROFILE="release_linux"
fi

# Source release variables to get $PRETTY_NAME
. /etc/os-release

echo "Building for: ${target}  with profile ${KANIDM_BUILD_PROFILE} & rust ${RUST_VERSION} on ${PRETTY_NAME}"

cargo build --target "$target" \
  --bin kanidm_unixd \
  --bin kanidm_unixd_tasks \
  --bin kanidm_ssh_authorizedkeys \
  --bin kanidm_ssh_authorizedkeys_direct \
  --bin kanidm-unix \
  --bin kanidm \
  --bin kanidmd \
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
