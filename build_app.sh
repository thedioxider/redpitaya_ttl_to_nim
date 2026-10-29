#!/usr/bin/env bash
# Builds the TTL2NIM app's generated files into out/.
#
# Usage: build_app.sh
#   - out/<name>.bit.bin          bitstream (via redpitaya_genbin.sh)
#   - out/<name>.dtso             device tree overlay, filled from design.info (compiled on the board)
#   - out/settings.conf           default settings file, every key commented at its default
#   - out/settings_defaults.hpp   the same defaults, compiled into the controller
# Requires jq, and bootgen for redpitaya_genbin.sh.
set -euo pipefail

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

"$repo/redpitaya_genbin.sh"

# -- Device tree overlay: the unit address is the hex address without 0x and leading zeros.
sed -e "s/@NAME@/$name/g" \
    -e "s/@GPIO_UNIT@/$(printf '%x' "$((gpio_addr))")/g" \
    -e "s/@GPIO_ADDR@/$gpio_addr/g" \
    -e "s/@GPIO_SIZE@/$gpio_size/g" \
    "$repo/app/overlay.dtso" > "$out/$name.dtso"
echo "Wrote $out/$name.dtso"

# -- Settings
{
    echo "# TTL2NIM app settings."
    echo "# Uncommented lines override the defaults; commented lines show them."
    echo "# Format: key = value; # starts a comment."
    echo
    jq -r 'to_entries[]
        | "# \(.key)=\(.value.default | tostring)"
          + (.value.description // "" | if . == "" then "" else "   # " + . end)' "$settings"
} > "$out/settings.conf"
echo "Wrote $out/settings.conf"

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
} > "$out/settings_defaults.hpp"
echo "Wrote $out/settings_defaults.hpp"
