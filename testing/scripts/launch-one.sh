#!/bin/bash

set -eu
# This script is not intended to be run standalone, as it expects
# a boatload of files & env variables to be set. Run run-all.sh instead!

arch="${1?}"
img="${2?}"

# shellcheck source=../lib/log.sh
source lib/log.sh

log "$GREEN" "Generating ssh keys & seed.img"
cloud-localds seed.img <(scripts/gen-user-data.sh)

log "$GREEN" "Generating EFI artifacts"

native_arch="$(uname -m)"
if [[ "$arch" != "$native_arch" ]]; then
	log "$RED" "Overriding arch is a very bad idea, hope you know what you're doing."
fi

case "$arch" in
	x86_64)
		if [[ "$arch" == "$native_arch" ]]; then
			MACHINE=q35
			CPU=host
  		ACCEL=(-accel kvm)
		else
			# Best we can do for cross arch emulation
			MACHINE=virt,gic-version=3
			CPU=max
			ACCEL=(-accel "tcg,thread=multi")
		fi
		EFI=/usr/share/OVMF/OVMF_CODE_4M.fd
		if [[ ! -e "$EFI" ]]; then
			>&2 echo "EFI image is missing: ${EFI}. You are likely missing the 'ovmf' package or have an incompatible version."
			exit 1
		fi
		VARSTORE=()
		DRIVE=(-drive "if=virtio,format=qcow2,file=${img}")
		;;
	aarch64)
		if [[ "$arch" == "$native_arch" ]]; then
			MACHINE=virt
			CPU=max
			ACCEL=(-accel kvm)
		else
			# Best we can do for cross arch emulation
			MACHINE=virt,gic-version=3
			CPU=max
			ACCEL=(-accel "tcg,thread=multi")
		fi

		# The QEMU aarch64 virt machine is super picky and needs an exactly 64MiB EFI image and a varstore.
		truncate -s 64m "${arch}_varstore.img"
		truncate -s 64m "${arch}_efi.img"
		dd if=/usr/share/qemu-efi-aarch64/QEMU_EFI.fd of="${arch}_efi.img" conv=notrunc
		VARSTORE=(-drive "if=pflash,format=raw,file=${arch}_varstore.img")
		EFI="${arch}_efi.img"
		DRIVE=(-drive "if=none,file=${img},id=hd0" -device "virtio-blk-device,drive=hd0")
		;;
	*)
		log "$RED" "Unsupported architecture: $arch"
		exit 1
		;;
esac



SSH_OPTS=(-i ssh_ed25519 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)

set +e  # ssh will be failing on purpose
# Loop forever attempting to run qemu, but give every try a finite wait time
attempt=1
while true; do
	retry=1
	log "$GREEN" "Booting $arch $MACHINE with $EFI from $img"
	set -x
	"qemu-system-$arch"  \
  	-machine type="${MACHINE}" -m 1024 \
  	-cpu ${CPU} -smp 4 \
  	"${ACCEL[@]}" \
  	-snapshot \
  	-drive "if=pflash,format=raw,file=${EFI},readonly=on" \
  	"${VARSTORE[@]}" \
  	"${DRIVE[@]}" \
  	-drive if=virtio,format=raw,file=seed.img \
  	-netdev id=net00,type=user,hostfwd=tcp::"${SSH_PORT}"-:22 \
  	-device virtio-net-pci,netdev=net00 \
  	-monitor unix:qemu-monitor.socket,server,nowait \
  	-serial "telnet:localhost:${TELNET_PORT},server,nowait" \
  	-display none -daemonize -pidfile qemu.pid || exit 1
set +x
	while [[  "$retry" -le "${QEMU_PATIENCE_LIMIT?}" ]]; do
		log "$GREEN" "Waiting for VM (attempt ${attempt?}, retry ${retry?}/${QEMU_PATIENCE_LIMIT?}).. try 'nc localhost 4321' to see what's going on if this is taking too long."
		output=$(ssh "${SSH_OPTS[@]}" -p "$SSH_PORT" -o ConnectTimeout=1 root@localhost whoami)
		# If login succeeded, break out of both loops
		[[ "$output" == "root" ]] && break 2
		sleep 10s
		(( retry++ ))
	done
	log "$RED" "Giving up on VM booting (attempt: ${attempt?}), kill & retry ..."
  [[ -f qemu.pid ]] && kill "$(cat qemu.pid)" ; ( rm qemu.pid 2>/dev/null )
	(( attempt++ ))
done
set -e

log "$GREEN" "Up! Transferring assets."
assets=(test_payload.sh kanidm_ppa.list)
if [[ "$USE_DEBDIR" != "false" ]]; then
	assets+=("$USE_DEBDIR"/*.deb)
elif [[ "$USE_LIVE" == "false" ]]; then
	if [[ -f "snapshot/kanidm_ppa.asc" ]]; then
		assets+=(snapshot/kanidm_ppa.asc)
	elif [[	"$ALLOW_UNSIGNED" == "false" ]]; then
		log "$RED" "Snapshot is missing kanidm_ppa.asc and ALLOW_UNSIGNED=false"
		exit 1
	fi
fi
scp "${SSH_OPTS[@]}" -P "$SSH_PORT" "${assets[@]}" root@localhost:

log "$GREEN" "Launching test payload..."
set +e
set -x
ssh "${SSH_OPTS[@]}" -p "$SSH_PORT" root@localhost \
	MISE_TASK_NAME="$MISE_TASK_NAME" \
	IDM_URI="$IDM_URI" \
	IDM_GROUP="$IDM_GROUP" \
	MIRROR_PORT="$MIRROR_PORT" \
	KANIDM_VERSION="$KANIDM_VERSION" \
	CATEGORY="$CATEGORY" \
	USE_LIVE="$USE_LIVE" \
	USE_DEBDIR="$USE_DEBDIR" \
	IDM_PORT="$IDM_PORT" \
	IDM_USER="$IDM_USER" \
	SSH_PUBLICKEY="\"$SSH_PUBLICKEY\"" \
	PRETEND_TARGET="$PRETEND_TARGET" \
	KANIDM_UPGRADE="$KANIDM_UPGRADE" \
	./test_payload.sh
set +x

log "$GREEN" "Done, killing qemu"
kill "$(cat qemu.pid)"
rm qemu.pid
