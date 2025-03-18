#!/bin/bash

set -eu
# This script is not intended to be run standalone, as it expects
# a boatload of files & env variables to be set. Run run-all.sh instead!

arch="${1?}"
img="${2?}"

>&2 echo "Generating ssh keys & seed.img"
cloud-localds seed.img <(scripts/gen-user-data.sh)

>&2 echo "Generating EFI artifacts"

native_arch="$(uname -m)"
if [[ "$arch" != "$native_arch" ]]; then
	>&2 echo "This is a very bad idea, go modify the script if this is what you truly want."
	exit 1 #  Remove this line if you're really sure.
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
		EFI=/usr/share/OVMF/OVMF_CODE.fd
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
		>&2 echo "Unsupported architecture"
		exit 1
		;;
esac


>&2 echo "Booting $arch $MACHINE with $EFI from $img"
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

SSH_OPTS=(-i ssh_ed25519 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)

set +e  # ssh will be failing on purpose
while true; do
	echo "Waiting for VM.. try 'nc localhost 4321' to see what's going on."
	output=$(ssh "${SSH_OPTS[@]}" -p "$SSH_PORT" -o ConnectTimeout=1 root@localhost whoami)
	[[ "$output" == "root" ]] && break
	sleep 10s
done
set -e

>&2 echo "Up! Transferring assets."
assets=(test_payload.sh kanidm_ppa.list)
if [[ "$USE_LIVE" == "false" ]]; then
	if [[ -f "snapshot/kanidm_ppa.asc" ]]; then
		assets+=(snapshot/kanidm_ppa.asc)
	elif [[	"$ALLOW_UNSIGNED" == "false" ]]; then
		>&2 echo "Snapshot is missing kanidm_ppa.asc and ALLOW_UNSIGNED=false"
		exit 1
	fi
fi
scp "${SSH_OPTS[@]}" -P "$SSH_PORT" "${assets[@]}" root@localhost:

>&2 echo "Launching test payload..."
set +e
set -x
ssh "${SSH_OPTS[@]}" -p "$SSH_PORT" root@localhost \
	IDM_URI="$IDM_URI" \
	IDM_GROUP="$IDM_GROUP" \
	MIRROR_PORT="$MIRROR_PORT" \
	KANIDM_VERSION="$KANIDM_VERSION" \
	CATEGORY="$CATEGORY" \
	USE_LIVE="$USE_LIVE" \
	IDM_PORT="$IDM_PORT" \
	IDM_USER="$IDM_USER" \
	SSH_PUBLICKEY="\"$SSH_PUBLICKEY\"" \
	./test_payload.sh
set +x

>&2 echo "Done, killing qemu"
kill "$(cat qemu.pid)"
rm qemu.pid
