#!/bin/bash

set -eu

MIRROR_PORT="${MIRROR_PORT:-31625}"

zip=$(readlink -f "${1?}")

mkdir -p snapshot && cd snapshot
python3 -m http.server -b 127.0.0.1 "$MIRROR_PORT" -d . &
MIRROR_PID="$!"
echo "$MIRROR_PID" > ../mirror.pid
>&2 echo "Mirror pid: $MIRROR_PID"

# Unzip last as it takes a bit of time, but it'll be ready by the 
# time  the first test pulls on the mirror.
# This allows recording the PID earlier and allows for cleanup on failures
unzip -qo "$zip"
