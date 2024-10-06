#!/bin/bash
scripts/install-deps.sh
scripts/get-images.sh

export SSH_PORT=2222

function prompt(){
  read -p "Happy? ^C to stop full run, enter to continue to next target."
}

function run(){
	distro=$1
	shift
	debs=("$@")
	sudo -E scripts/launch-one.sh "$target" images/${distro}-*-${arch}.* ${debs[@]} || exit 1
	prompt
	sleep 2s  # Wait for qemu to release ports
}

### Sequencing of permutations. The defaults only test current stable on current native arch
# You could just enable aarch64 manually below, but better off running on a pi5 natively!

target="$(uname -m)"
arch="$(dpkg --print-architecture)"

#target=aarch64
#arch=arm64

run debian-12 debs/stable/stable-debian-12-${target}-unknown-linux-gnu/kanidm*
run jammy debs/stable/stable-ubuntu-22.04-${target}-unknown-linux-gnu/kanidm*
run noble debs/stable/stable-ubuntu-24.04-${target}-unknown-linux-gnu/kanidm*

