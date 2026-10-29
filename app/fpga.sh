#!/bin/sh
# Loads our bitstream with its overlay; Bazaar runs this when the app starts.
# Mirrors /opt/redpitaya/sbin/overlay.sh, but takes the files from the app folder.

dir=$(cd "$(dirname "$0")" && pwd)
. "$dir/conf_get.sh"
if ! name=$(conf_get "$dir/design.info" name); then
    echo "No name in $dir/design.info" >&2
    exit 1
fi

overlay=/configfs/device-tree/overlays/Full
# Checksum of the bitstream this script last programmed.
programmed=/tmp/$name.programmed

rmdir "$overlay" 2> /dev/null
rm /tmp/loaded_fpga.inf 2> /dev/null
sleep 0.5

# Removing the overlay doesn't unload the bitstream, so skip programming (and the output gap) if
# the FPGA still holds this exact file: we programmed it, and the kernel programmed nothing since.
sum=$(md5sum "$dir/$name.bit.bin" | cut -d' ' -f1)
last=$(dmesg | grep 'fpga_manager.*: writing ' | tail -n 1)
if [ -n "$sum" ] && [ "$(cat "$programmed" 2> /dev/null)" = "$sum" ] &&
    case $last in *" writing $name.bit.bin to "*) true ;; *) false ;; esac; then
    if mkdir "$overlay" && cat "$dir/${name}_uio.dtbo" > "$overlay/dtbo" &&
        [ "$(cat "$overlay/status")" = applied ]; then
        printf '%s' "$name" > /tmp/loaded_fpga.inf
        exit 0
    fi
    rmdir "$overlay" 2> /dev/null
fi

rm "$programmed" 2> /dev/null
if /opt/redpitaya/bin/fpgautil -b "$dir/$name.bit.bin" -o "$dir/$name.dtbo" -n Full; then
    printf '%s' "$name" > /tmp/loaded_fpga.inf
    printf '%s' "$sum" > "$programmed"
else
    rm /tmp/loaded_fpga.inf 2> /dev/null
    exit 1
fi
