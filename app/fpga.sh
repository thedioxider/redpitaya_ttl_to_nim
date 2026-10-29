#!/bin/sh
# Loads our bitstream with its overlay; Bazaar runs this when the app starts.
# Mirrors /opt/redpitaya/sbin/overlay.sh, but takes the files from the app folder.

dir=$(cd "$(dirname "$0")" && pwd)
. "$dir/conf_get.sh"
if ! name=$(conf_get "$dir/design.info" name); then
    echo "No name in $dir/design.info" >&2
    exit 1
fi

rmdir /configfs/device-tree/overlays/Full 2> /dev/null
rm /tmp/loaded_fpga.inf 2> /dev/null
sleep 0.5

if /opt/redpitaya/bin/fpgautil -b "$dir/$name.bit.bin" -o "$dir/$name.dtbo" -n Full; then
    printf '%s' "$name" > /tmp/loaded_fpga.inf
else
    rm /tmp/loaded_fpga.inf 2> /dev/null
    exit 1
fi
