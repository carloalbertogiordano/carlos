#!/bin/bash
# Carlos first-boot flatpak installer
# Runs exclusively on TTY1, blocks display-manager until complete.

set -uo pipefail

# ── terminal ──────────────────────────────────────────────────────────────────
[[ -z "${TERM:-}" ]] && export TERM=linux

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

DONE_FILE="/var/lib/carlos/flatpak-firstboot.done"
LOG_FILE="/var/log/carlos-flatpak-setup.log"
FAILED=()

FLATPAKS=(
    com.bitwarden.desktop
    com.github.tchx84.Flatseal
    com.github.xournalpp.xournalpp
    com.protonvpn.www
    com.prusa3d.PrusaSlicer
    com.usebottles.bottles
    com.ktechpit.orion
    io.dbeaver.DBeaverCommunity
    io.github.dvlv.boxbuddyrs
    md.obsidian.Obsidian
    net.pcsx2.PCSX2
    org.ghidra_sre.Ghidra
    org.gimp.GIMP
    org.inkscape.Inkscape
    org.kde.okular
    org.mozilla.firefox
    org.videolan.VLC
    org.torproject.torbrowser-launcher
    ai.lmstudio.lm-studio
    com.anydesk.Anydesk
    com.brave.Browser
    com.discordapp.Discord
    com.valvesoftware.Steam
    com.visualstudio.code
)

# ── helpers ───────────────────────────────────────────────────────────────────

print_header() {
    clear
    printf "${BOLD}${CYAN}"
    printf "  ┌───────────────────────────────────────────────────────┐\n"
    printf "  │           Carlos OS — First Boot Setup                │\n"
    printf "  └───────────────────────────────────────────────────────┘\n"
    printf "${NC}\n"
    printf "  ${YELLOW}Do not power off. The system will reboot when done.${NC}\n\n"
}

progress_bar() {
    local ok=$1 total=$2
    local width=52
    local filled=$(( ok * width / total ))
    local bar="" empty="" i
    for ((i=0; i<filled; i++));        do bar+="█"; done
    for ((i=filled; i<width; i++));    do empty+="░"; done
    printf "  ${CYAN}%s${DIM}%s${NC}  %d/%d installed\n" "$bar" "$empty" "$ok" "$total"
}

find_desktop() {
    local home
    home=$(getent passwd | awk -F: '$3>=1000 && $3<65534 && $7!="/sbin/nologin" {print $6}' | head -1)
    if [[ -n "$home" ]]; then
        mkdir -p "$home/Desktop"
        echo "$home/Desktop"
    else
        mkdir -p /root/Desktop
        echo "/root/Desktop"
    fi
}

wait_for_internet() {
    local delay=5
    while ! curl -sf --max-time 4 https://flathub.org/repo/flathub.flatpakrepo -o /dev/null; do
        for ((i=delay; i>0; i--)); do
            printf "\r  ${YELLOW}No internet — retrying in %2ds...${NC}   " "$i"
            sleep 1
        done
        printf "\r  ${YELLOW}Checking connection...${NC}                  "
        [[ $delay -lt 60 ]] && delay=$((delay+5))
    done
    printf "\r  ${GREEN}Internet connection ready.${NC}               \n\n"
}

# ── main ──────────────────────────────────────────────────────────────────────

mkdir -p /var/lib/carlos
mkdir -p /var/log

print_header

printf "  Checking internet connection...\n"
wait_for_internet

total=${#FLATPAKS[@]}
printf "  Installing ${BOLD}%d${NC} applications from Flathub...\n\n" "$total"

current=0
ok=0
for app in "${FLATPAKS[@]}"; do
    ((current++))
    printf "  [%2d/%d] %-50s" "$current" "$total" "$app"

    if flatpak install --system --noninteractive flathub "$app" \
            >> "$LOG_FILE" 2>&1; then
        printf "${GREEN}✓${NC}\n"
        ((ok++))
    else
        printf "${RED}✗ FAILED${NC}\n"
        FAILED+=("$app")
    fi
done

printf "\n"
progress_bar "$ok" "$total"
printf "\n"

# ── cleanup unused runtimes ───────────────────────────────────────────────────
printf "  Removing unused runtimes...\n"
flatpak uninstall --system --unused -y >> "$LOG_FILE" 2>&1 || true
printf "\n"

# ── failure report ────────────────────────────────────────────────────────────
if [[ ${#FAILED[@]} -gt 0 ]]; then
    desktop=$(find_desktop)
    fail_file="$desktop/flatpak-install-failed.txt"
    {
        printf "The following apps failed to install during first-boot setup.\n"
        printf "To retry, run each command as root:\n\n"
        for f in "${FAILED[@]}"; do
            printf "  flatpak install --system flathub %s\n" "$f"
        done
        printf "\nFull install log: %s\n" "$LOG_FILE"
    } > "$fail_file"
    printf "  ${RED}${BOLD}%d app(s) failed.${NC} See: ${DIM}%s${NC}\n\n" "${#FAILED[@]}" "$fail_file"
else
    printf "  ${GREEN}${BOLD}All %d applications installed successfully.${NC}\n\n" "$total"
fi

# ── finish ────────────────────────────────────────────────────────────────────
touch "$DONE_FILE"
systemctl disable flatpak-firstboot.service 2>/dev/null || true

printf "  ${BOLD}Setup complete. Rebooting in 5 seconds...${NC}\n"
for ((i=5; i>0; i--)); do
    printf "\r  ${BOLD}Setup complete. Rebooting in %ds...${NC}  " "$i"
    sleep 1
done
printf "\n"
systemctl reboot
