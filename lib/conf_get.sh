# Reads values from this project's "key = value" files (design.info, settings.conf).
# POSIX sh; meant to be sourced.
#
# Grammar: one "key = value" per line, spaces around "=" optional, key of [a-z0-9_],
# value a single token; "#" starts a comment. Other lines are ignored.

# Usage: conf_get FILE KEY
# Prints KEY's value (the last one if repeated). Fails with no output if FILE or KEY is missing.
conf_get() {
    [ -f "$1" ] || return 1
    awk -v key="$2" '
        { sub(/\r$/, ""); sub(/#.*/, "") }
        /^[ \t]*[a-z0-9_]+[ \t]*=[ \t]*[^ \t]+[ \t]*$/ {
            k = $0; sub(/^[ \t]*/, "", k); sub(/[ \t]*=.*/, "", k)
            if (k == key) {
                v = $0; sub(/^[^=]*=[ \t]*/, "", v); sub(/[ \t]*$/, "", v)
                found = 1
            }
        }
        END { if (found) print v; exit !found }
    ' "$1"
}
