# shellcheck disable=SC2034

OSARCH="${OSARCH:-$(dpkg --print-architecture)}"

# Individual target name mapped images.
# This is used by the other scripts via include.
trixie="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-${OSARCH}.qcow2"
bookworm="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-${OSARCH}.qcow2"
noble="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-${OSARCH}.img"
jammy="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-${OSARCH}.img"
plucky="https://cloud-images.ubuntu.com/plucky/current/plucky-server-cloudimg-${OSARCH}.img"
questing="https://cloud-images.ubuntu.com/questing/current/questing-server-cloudimg-${OSARCH}.img"
