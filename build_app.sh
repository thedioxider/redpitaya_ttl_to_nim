#!/usr/bin/env bash
# Builds the TTL2NIM app into out/ttl2nim/, ready to install, and offers to install it.
# Besides app/ sources, the folder gets generated files:
#   - <name>.bit.bin              bitstream (via redpitaya_genbin.sh)
#   - <name>.dtso                 device tree overlay with the bitstream, and
#   - <name>_uio.dtso             the UIO node alone; filled from design.info (compiled on the board)
#   - settings.conf               default settings file, every key commented at its default
#   - src/settings_defaults.hpp   the same defaults, compiled into the controller
#
# Usage: build_app.sh [--no-install]
# Requires jq, and bootgen for redpitaya_genbin.sh.
set -euo pipefail

ask_install=true
for arg in "$@"; do
    case $arg in
        --no-install) ask_install=false ;;
        *) echo "Unknown argument: $arg" >&2; exit 1 ;;
    esac
done

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$repo/lib/conf_get.sh"
out="$repo/out"
design="$repo/design.info"
settings="$repo/app/settings.json"

fail() {
    echo "$*" >&2
    exit 1
}

# Prints design.info's KEY, failing unless its value matches the extended regex PATTERN.
design_value() {
    local value
    value=$(conf_get "$design" "$1") || fail "No $1 in $design"
    [[ $value =~ $2 ]] || fail "Invalid $1 in $design: $value"
    echo "$value"
}

command -v jq > /dev/null || fail "jq not found."

name=$(design_value name '^[a-z0-9_]+$')
gpio_addr=$(design_value gpio_addr '^0x[0-9a-fA-F]{1,8}$')
gpio_size=$(design_value gpio_size '^0x[0-9a-fA-F]{1,8}$')

# Settings keys and default values must fit the settings.conf grammar, and descriptions must
# be single-line, since they become trailing comments. Checked before the slow bitstream step.
errors=$(jq -r '
    if type != "object" then "top level must be an object" else
        to_entries[]
        | .key as $k
        | if (.key | test("^[a-z0-9_]+$") | not) then "\($k): key must match [a-z0-9_]+"
          elif (.value | type) != "object" then "\($k): must be an object"
          elif (.value.default | type) as $t | ($t != "number" and $t != "string") then
              "\($k): default must be a number or string"
          elif (.value.default | tostring | test("^[^\\s#]+$") | not) then
              "\($k): default must be one token without spaces or #"
          elif (.value.description // "" | test("[[:cntrl:]]")) then
              "\($k): description must be a single line"
          else empty end
    end
' "$settings") || fail "Can't parse $settings"
[[ -z $errors ]] || fail "Invalid $settings:"$'\n'"$errors"

stage="$out/ttl2nim"
if [[ -d $stage ]]; then
    rm -r "$stage"
fi
mkdir -p "$stage/info" "$stage/src" "$stage/css" "$stage/js" "$stage/assets"

"$repo/redpitaya_genbin.sh"
cp "$out/$name.bit.bin" "$stage/"

# -- Device tree overlays: the unit address is the hex address without 0x and leading zeros.
for overlay in overlay:"$name" overlay_uio:"${name}_uio"; do
    sed -e "s/@NAME@/$name/g" \
        -e "s/@GPIO_UNIT@/$(printf '%x' "$((gpio_addr))")/g" \
        -e "s/@GPIO_ADDR@/$gpio_addr/g" \
        -e "s/@GPIO_SIZE@/$gpio_size/g" \
        "$repo/app/${overlay%%:*}.dtso" > "$stage/${overlay#*:}.dtso"
done

# -- Settings
{
    echo "# TTL2NIM app settings."
    echo "# Uncommented lines override the defaults; commented lines show them."
    echo "# Format: key = value; # starts a comment."
    echo
    jq -r 'to_entries[]
        | "# \(.key)=\(.value.default | tostring)"
          + (.value.description // "" | if . == "" then "" else "   # " + . end)' "$settings"
} > "$stage/settings.conf"

{
    echo "// Generated from app/settings.json by build_app.sh. Do not edit."
    echo "#pragma once"
    echo "#include \"settings_loader.hpp\""
    echo
    if [[ $(jq length "$settings") == 0 ]]; then
        # C++ has no zero-length arrays.
        echo "static const SettingDef* const kSettingDefaults = nullptr;"
        echo "static const size_t kSettingDefaultsCount = 0;"
    else
        echo "static const SettingDef kSettingDefaults[] = {"
        jq -r 'to_entries[]
            | "    {\(.key | tojson), \(.value.default | tostring | tojson), \(.value.description // "" | tojson)},"' \
            "$settings"
        echo "};"
        echo "static const size_t kSettingDefaultsCount = sizeof(kSettingDefaults) / sizeof(kSettingDefaults[0]);"
    fi
} > "$stage/src/settings_defaults.hpp"

# -- App sources, from explicit lists so nothing else ends up on the board.
app_files=(
    info/info.json info/icon.png
    index.html css/style.css js/app.js js/format.js js/theme.js assets/theme.svg assets/arrow.svg
    fpga.sh nginx.conf install.sh
    src/Makefile
)
for f in "${app_files[@]}"; do
    [[ -f $repo/app/$f ]] || fail "Missing app/$f"
    cp "$repo/app/$f" "$stage/$f"
done
cp "$repo"/app/src/*.cpp "$repo"/app/src/*.hpp "$stage/src/"
cp "$design" "$repo/lib/conf_get.sh" "$stage/"

# Bazaar only runs fpga.sh if fpga.conf isn't empty; it historically held the bitstream path.
echo "/opt/redpitaya/www/apps/ttl2nim/$name.bit.bin" > "$stage/fpga.conf"
revision=$(git -C "$repo" rev-parse --short HEAD 2> /dev/null || echo unknown)
sed -i.bak "s/REVISION/$revision/" "$stage/info/info.json" && rm "$stage/info/info.json.bak"
echo "Staged $stage"

if [[ $ask_install == true ]]; then
    host=
    read -rp "Install to a board now? Board address (empty to skip): " host || true
    if [[ -n $host ]]; then
        "$stage/install.sh" "$host"
    fi
fi
