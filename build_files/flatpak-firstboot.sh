#!/bin/bash
# Extra-data Flatpaks require bwrap which is unavailable in container builds.
# This script runs once at first boot to complete their installation.

set -euo pipefail

STAMP=/var/lib/carlos/flatpak-firstboot.done
[ -f "$STAMP" ] && exit 0

mkdir -p /var/lib/carlos

flatpak remote-add --if-not-exists --system flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo

FLATPAKS=(
    ai.lmstudio.lm-studio
    com.anydesk.Anydesk
    com.valvesoftware.Steam
    com.visualstudio.code
)

all_ok=true
for app in "${FLATPAKS[@]}"; do
    if flatpak info --system "$app" &>/dev/null; then
        echo "[firstboot] $app already installed, skipping"
        continue
    fi
    flatpak install --system --noninteractive flathub "$app" \
        && echo "[firstboot] $app installed" \
        || { echo "[firstboot][warn] $app failed — will retry next boot"; all_ok=false; }
done

$all_ok && touch "$STAMP"
