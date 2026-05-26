#!/bin/bash

set -ouex pipefail

# Add stable Flathub remote
flatpak remote-add --if-not-exists --system flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo

# Install all apps in one call — runtimes are deduplicated automatically
flatpak install --system --noninteractive flathub \
    ai.lmstudio.lm-studio \
    com.anydesk.Anydesk \
    com.bitwarden.desktop \
    com.brave.Browser \
    com.discordapp.Discord \
    com.github.micahflee.torbrowser-launcher \
    com.github.tchx84.Flatseal \
    com.github.xournalpp.xournalpp \
    com.google.Chrome \
    com.ktechpit.orion \
    com.protonvpn.www \
    com.prusa3d.PrusaSlicer \
    com.usebottles.bottles \
    com.valvesoftware.Steam \
    com.visualstudio.code \
    io.dbeaver.DBeaverCommunity \
    io.github.dvlv.boxbuddyrs \
    md.obsidian.Obsidian \
    net.pcsx2.PCSX2 \
    net.thunderbird.Thunderbird \
    org.gimp.GIMP \
    org.ghidra_sre.Ghidra \
    org.inkscape.Inkscape \
    org.kde.okular \
    org.mozilla.firefox \
    org.videolan.VLC

# Remove orphaned runtimes
flatpak uninstall --system --unused -y
