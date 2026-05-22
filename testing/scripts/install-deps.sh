#!/bin/bash

case $(uname -m) in
  x86_64)
    qemu_system="qemu-system-x86"
    ;;
  aarch64)
    qemu_system="qemu-system-arm64"
    ;;
    *)
    >&2 echo "Unsupported platform"
    exit 1
    ;;
esac

sudo apt install cloud-image-utils "$qemu_system"
