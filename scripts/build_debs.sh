#!/usr/bin/bash

# This script chains together the pieces needed to package all supported deb packages.
# For simplicity, it does not run the required build(s) first or install dependencies, that's on you / the CI pipeline.
# If you're a human, the best way is to install the dev dependencies with the script in the main kanidm/kanidm repo:
# `PACKAGING=1 scripts/install_ubuntu_dependencies.sh`

set -e

# The target triplet(s) must be given as args.

if [ -z "${VERBOSE}" ]; then
    VERBOSE=""
else
    VERBOSE="-v"
fi


if [ -f "${HOME}/.cargo/env" ]; then
    # shellcheck disable=SC1091
    source "${HOME}/.cargo/env"
fi

# if we can't find cargo then need to update the path
if [ "$(which cargo | wc -l)" -eq 0 ]; then
    if echo "$PATH" | grep -q '.cargo/bin'; then
        echo "Updating path to include local cargo dir"
        export PATH="$HOME/.cargo/bin:$PATH"
        if [ "$(which cargo | wc -l)" -eq 0 ]; then
            echo "Still couldn't find cargo, bailing!"
            exit 1
        fi
    fi
fi

if [ "$(which cargo-deb | wc -l)" -eq 0 ]; then
	echo "Installing missing cargo-deb"
	cargo install cargo-deb
fi


# Get the version. cargo-deb does have some version handling but it fails at a few key items such as the `-dev` suffix.
# if we're in a github action, then it's easy to get the commit hash
if [ -n "${GITHUB_SHA}" ]; then
    GIT_HEAD="${GITHUB_SHA}"
else
    git config --global --add safe.directory "$PWD"
    GIT_HEAD="$(git rev-parse HEAD)"
fi
KANIDM_VERSION="$(grep -ioE 'version.*' Cargo.toml | head -n1 | awk '{print $NF}' | tr -d '"' | sed -e 's/-/~/')"
DATESTR="$(date +%Y%m%d%H%M)"
GIT_COMMIT="${GIT_HEAD:0:7}"
DEBIAN_REV="${DATESTR}+${GIT_COMMIT}"
PACKAGE_VERSION="${KANIDM_VERSION}-${DEBIAN_REV}"

echo "Package version: ${PACKAGE_VERSION}"

echo "Updating changelog"
mkdir -p target/debian
sed -E \
    "s/#DATE#/$(date -R)/" \
    platform/debian/kanidm_deb_packaging/templates/changelog  | \
    sed -E "s/#VERSION#/${PACKAGE_VERSION}/" | \
    sed -E "s/#GIT_COMMIT#/${GIT_COMMIT}/" | \
    sed -E "s/#PACKAGE#/${PACKAGE}/" > target/debian/changelog

targets=("$@")
for target in "${targets[@]}"; do
    echo "Packaging for: ${target}"
    # Build debs per target, per workspace
    for workspace in kanidm_unix_int pam_kanidm nss_kanidm; do
        echo "Building deb for: ${workspace}"
        cargo deb "$VERBOSE" -p "$workspace" --no-build --target "$target" --deb-version "$PACKAGE_VERSION"
    done
    echo "Target ${target} done, packages:"
    find "target/${target}" -maxdepth 3 -name '*.deb'
done

echo "All targets ${target} done, packages:"
find "target/" -name '*.deb'
