#!/bin/bash
# Register Flathub remote. All app installs happen at first boot via
# flatpak-firstboot.service (TTY1 installer with progress UI).

set -ouex pipefail

flatpak remote-add --if-not-exists --system flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo
