# shellcheck disable=SC2034

OSARCH="${OSARCH:-$(dpkg --print-architecture)}"

# Individual target name mapped images.
# This is used by the other scripts via include.
bookworm="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-${OSARCH}.qcow2"
noble="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-${OSARCH}.img"
jammy="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-${OSARCH}.img"
oracular="https://cloud-images.ubuntu.com/oracular/current/oracular-server-cloudimg-${OSARCH}.img"
plucky="https://cloud-images.ubuntu.com/plucky/current/plucky-server-cloudimg-${OSARCH}.img"
