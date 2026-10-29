#!/usr/bin/env bash
# Installs this app folder on a Red Pitaya.
#
# Usage:
#   install.sh HOST   from a PC: copies this folder to the board over SSH and installs it there
#   install.sh        on the board: installs this folder into /opt/redpitaya/www/apps/ttl2nim
set -euo pipefail

src=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
apps=/opt/redpitaya/www/apps
app=$apps/ttl2nim

fail() {
    echo "$*" >&2
    exit 1
}

# -- From a PC: one SSH connection for the copy and the remote install.
install_remote() {
    host=$1  # global: the exit trap needs it
    [[ $host == *@* ]] || host=root@$host

    ctl=$(mktemp -d)
    opts=(-o "ControlPath=$ctl/socket")
    remote_tmp=
    cleanup_remote() {
        if [[ -n $remote_tmp ]]; then
            ssh "${opts[@]}" "$host" "rm -rf '$remote_tmp'" || true
        fi
        ssh "${opts[@]}" -O exit "$host" 2> /dev/null || true
        rm -r "$ctl"
    }
    trap cleanup_remote EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM

    if ! ssh "${opts[@]}" -o ControlMaster=yes -o ControlPersist=60 -fN "$host"; then
        echo "Can't keep a shared SSH connection; you may be asked for the password more than once." >&2
        opts=()
    fi

    remote_tmp=$(ssh "${opts[@]}" "$host" "mktemp -d /tmp/ttl2nim-install.XXXXXX")
    local remote_src
    remote_src=$remote_tmp/$(basename "$src")
    echo "Copying to $host:$remote_src"
    scp -q -r "${opts[@]}" "$src" "$host:$remote_tmp/"
    ssh -t "${opts[@]}" "$host" "bash '$remote_src/install.sh' --remote"
    echo "Open http://${host#*@}/ttl2nim/"
}

# -- On the board: build next to the installed app, then swap, so a failure keeps the old one.
install_local() {
    command -v dtc > /dev/null || fail "dtc not found on the board."

    new=$apps/.ttl2nim.new
    was_ro=false
    # Runs after the nginx restart: nginx holding the deleted old controller blocks a ro remount.
    cleanup_local() {
        # A built leftover would show up as a second app.
        rm -rf "$new"
        if [[ $was_ro == true ]] && ! mount -o remount,ro /opt/redpitaya; then
            echo "Couldn't remount /opt/redpitaya read-only; it stays read-write until reboot." >&2
        fi
    }
    trap cleanup_local EXIT

    if [[ ! -w $apps ]]; then
        local answer=
        read -rp "/opt/redpitaya is read-only. Remount it read-write for the install? [y/N] " answer || true
        [[ $answer == [yY]* ]] || fail "Not installed."
        was_ro=true
        mount -o remount,rw /opt/redpitaya
    fi

    local log
    log=$(mktemp /tmp/ttl2nim-build.XXXXXX)
    rm -rf "$new"
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM
    cp -r "$src" "$new"
    if [[ -f $app/settings.conf ]]; then
        cp "$app/settings.conf" "$new/settings.conf"
    fi

    echo "Building..."
    if ! make -s -j"$(nproc)" -C "$new/src" INSTALL_DIR=/opt/redpitaya 2>&1 | tee "$log"; then
        fail "Build failed (log: $log). The installed app is unchanged."
    fi

    rm -rf "$app"
    mv "$new" "$app"
    echo "Installed to $app"

    if ! /opt/redpitaya/sbin/nginx -p /opt/redpitaya/www -t > "$log" 2>&1; then
        cat "$log" >&2
        fail "nginx config check failed; nginx was not restarted."
    fi
    systemctl restart redpitaya_nginx

    rm "$log"
    # From a PC, the PC side prints the address it used.
    if [[ $1 != --remote ]]; then
        echo "Open http://$(hostname -I | cut -d' ' -f1)/ttl2nim/"
    fi
}

if [[ -d /opt/redpitaya ]]; then
    install_local "${1:-}"
elif (($# > 0)); then
    install_remote "$1"
else
    host=
    read -rp "Board address (e.g. rp-xxxxxx.local): " host || true
    [[ -n $host ]] || fail "No board address given."
    install_remote "$host"
fi
