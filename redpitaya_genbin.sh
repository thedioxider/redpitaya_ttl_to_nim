#!/usr/bin/env bash
# Converts Vivado's .bit into the .bit.bin format that Red Pitaya's fpgautil loads.
#
# Usage: redpitaya_genbin.sh [PATH]
#   PATH  bitstream, with or without .bit; writes PATH.bit.bin next to it
#   none  finds Vivado's bitstream under build/ and writes out/ttl2nim.bit.bin
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
auto_out="$repo/out/ttl2nim.bit.bin"

if ! command -v bootgen > /dev/null; then
    echo "bootgen not found. It ships with Vivado/Vitis: source their settings64.sh first." >&2
    exit 1
fi

mtime() { date -r "$1" '+%Y-%m-%d %H:%M'; }

# Sets $bit to Vivado's implementation bitstream, asking the user when it's ambiguous.
find_bit() {
    local bits=() f n i
    for f in "$repo"/build/redpitaya_ttl_to_nim.runs/impl_*/*.bit; do
        [[ -f $f ]] && bits+=("$f")
    done

    case ${#bits[@]} in
        0)
            echo 'No bitstream found. Run "Generate Bitstream" in Vivado first.' >&2
            read -rp 'Path to .bit: ' bit
            if [[ -z $bit ]]; then
                echo "No path given." >&2
                exit 1
            fi
            ;;
        1)
            bit=${bits[0]}
            echo "Using $bit ($(mtime "$bit"))"
            ;;
        *)
            echo "Several bitstreams found:"
            for i in "${!bits[@]}"; do
                echo "  $((i + 1))) ${bits[i]} ($(mtime "${bits[i]}"))"
            done
            read -rp 'Number: ' n
            if ! [[ $n =~ ^[0-9]+$ ]] || ((n < 1 || n > ${#bits[@]})); then
                echo "Invalid choice: $n" >&2
                exit 1
            fi
            bit=${bits[n - 1]}
            ;;
    esac
}

if (($# > 0)); then
    bit=${1%.bit}.bit
    out=${bit}.bin
else
    find_bit
    bit=${bit%.bit}.bit
    out=$auto_out
    mkdir -p "$(dirname "$out")"
fi

if [[ ! -f $bit ]]; then
    echo "No such bitstream: $bit" >&2
    exit 1
fi

# BIF paths can't contain spaces, so convert a copy under a fixed name.
tmp=$(mktemp -d "$(dirname "$out")/.genbin.XXXXXX")
cleanup() {
    if [[ -d $tmp ]]; then
        rm -r "$tmp"
    fi
}
trap cleanup EXIT

cp "$bit" "$tmp/bitstream.bit"
printf 'all:{ bitstream.bit }\n' > "$tmp/bitstream.bif"
(cd "$tmp" && bootgen -image bitstream.bif -arch zynq -process_bitstream bin -o bitstream.bit.bin -w)

if [[ ! -f $tmp/bitstream.bit.bin ]]; then
    echo "bootgen didn't produce a .bit.bin" >&2
    exit 1
fi
mv "$tmp/bitstream.bit.bin" "$out"
echo "Wrote $out"
