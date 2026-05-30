#!/bin/bash

set -ouex pipefail

# Add stable Flathub remote
flatpak remote-add --if-not-exists --system flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo

# Helper: install one flatpak, warn on failure (extra-data apps need bwrap
# which is not available in container builds — they will install on first boot)
install_flatpak() {
    flatpak install --system --noninteractive flathub "$1" \
        || echo "[warn] flatpak $1 failed (likely extra-data/bwrap) — will install at runtime"
}

# Self-contained flatpaks (no extra-data, no bwrap needed)
install_flatpak com.bitwarden.desktop
install_flatpak com.github.tchx84.Flatseal
install_flatpak com.github.xournalpp.xournalpp
install_flatpak com.protonvpn.www
install_flatpak com.prusa3d.PrusaSlicer
install_flatpak com.usebottles.bottles
install_flatpak com.ktechpit.orion
install_flatpak io.dbeaver.DBeaverCommunity
install_flatpak io.github.dvlv.boxbuddyrs
install_flatpak md.obsidian.Obsidian
install_flatpak net.pcsx2.PCSX2
install_flatpak org.ghidra_sre.Ghidra
install_flatpak org.gimp.GIMP
install_flatpak org.inkscape.Inkscape
install_flatpak org.kde.okular
install_flatpak org.mozilla.firefox
install_flatpak org.videolan.VLC
install_flatpak org.torproject.torbrowser-launcher

# Extra-data flatpaks — may fail in container builds due to bwrap restriction.
# They will complete installation on first user login.
install_flatpak ai.lmstudio.lm-studio
install_flatpak com.anydesk.Anydesk
install_flatpak com.brave.Browser
install_flatpak com.discordapp.Discord
install_flatpak com.valvesoftware.Steam
install_flatpak com.visualstudio.code

# Remove orphaned runtimes
flatpak uninstall --system --unused -y
