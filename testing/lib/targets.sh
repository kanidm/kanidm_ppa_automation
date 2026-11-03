# shellcheck disable=SC2034

OSARCH="${OSARCH:-$(dpkg --print-architecture)}"

# Individual target name mapped images.
# This is used by the other scripts via include.

# Debian
trixie="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-${OSARCH}.qcow2"
bookworm="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-${OSARCH}.qcow2"

# Ubuntu
noble="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-${OSARCH}.img"
stonking="https://cloud-images.ubuntu.com/stonking/current/stonking-server-cloudimg-${OSARCH}.img"
resolute="https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-${OSARCH}.img"
