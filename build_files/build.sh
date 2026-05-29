#!/bin/bash

set -ouex pipefail

FEDORA_VER=$(rpm -E %fedora)

## ── DNF CONFIG ───────────────────────────────────────────────────────────────
sed -i '/^\[main\]/a max_parallel_downloads=10' /etc/dnf/dnf.conf

## ── REPOS ────────────────────────────────────────────────────────────────────
# RPM Fusion (free + nonfree)
dnf -y install \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm"

# fedora-multimedia (in base image) ships newer vvenc-libs than rpmfusion-free.
# Exclude vvenc-libs from rpmfusion repos globally to prevent downgrade conflicts
# on any package that transitively depends on it (ffmpeg, libheif-freeworld, …).
for repo in /etc/yum.repos.d/rpmfusion-free*.repo; do
    grep -q '^excludepkgs=' "$repo" \
        && sed -i 's/^excludepkgs=/excludepkgs=vvenc-libs /' "$repo" \
        || echo 'excludepkgs=vvenc-libs' >> "$repo"
done

# CachyOS kernel (COPR bieszczaders/kernel-cachyos)
dnf copr enable -y bieszczaders/kernel-cachyos

# Nautilus open-any-terminal
curl -Lo /etc/yum.repos.d/nautilus-open-any-terminal.repo \
    "https://copr.fedorainfracloud.org/coprs/monkeygold/nautilus-open-any-terminal/repo/fedora-${FEDORA_VER}/monkeygold-nautilus-open-any-terminal-fedora-${FEDORA_VER}.repo"

## ── KERNEL: CachyOS ──────────────────────────────────────────────────────────
# 05-rpmostree.install runs dracut during %posttrans but modules.dep doesn't
# exist yet at that point in a container build — bootc generates initramfs at
# deploy time anyway, so disable the hook for the duration of this install.
mv /usr/lib/kernel/install.d/05-rpmostree.install \
   /usr/lib/kernel/install.d/05-rpmostree.install.disabled 2>/dev/null || true

dnf -y install kernel-cachyos kernel-cachyos-devel dkms

# Build modules.dep for the new kernel so dkms and depmod consumers work
CACHYOS_VER=$(rpm -q kernel-cachyos-core --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' 2>/dev/null | head -1)
[ -n "$CACHYOS_VER" ] && depmod -a "$CACHYOS_VER" || true

# Remove stock Fedora kernel — keep only CachyOS
STOCK=$(rpm -qa 'kernel' 'kernel-core' 'kernel-modules' 'kernel-modules-core' \
    'kernel-modules-extra' 'kernel-devel' 2>/dev/null | grep -v cachyos || true)
[ -n "$STOCK" ] && dnf -y remove $STOCK || true

# Restore hook so future rpm operations behave normally
mv /usr/lib/kernel/install.d/05-rpmostree.install.disabled \
   /usr/lib/kernel/install.d/05-rpmostree.install 2>/dev/null || true

## ── EDITORS ──────────────────────────────────────────────────────────────────
# Remove vim-minimal (provides /usr/bin/vi — not wanted)
# vim-data and vim-filesystem have no binaries, leave them as dep placeholders
rpm -e --nodeps vim-minimal 2>/dev/null || true
dnf -y install nano nano-default-editor

## ── VIRTUALIZATION (KVM/QEMU/libvirt) ────────────────────────────────────────
dnf -y install \
    libvirt virt-manager virt-install virt-viewer virt-top \
    qemu-kvm \
    edk2-ovmf \
    swtpm swtpm-tools \
    spice-vdagent \
    virtiofsd \
    guestfs-tools \
    virt-win-reg

## ── CONTAINERS ───────────────────────────────────────────────────────────────
dnf -y install distrobox toolbox

# System-wide distrobox defaults: GPU, FUSE, Wayland, SELinux-off, debug caps
# Users can override in ~/.config/distrobox/distrobox.conf
mkdir -p /etc/distrobox/
cat > /etc/distrobox/distrobox.conf << 'EOF'
container_additional_flags="--device /dev/dri --device /dev/fuse --security-opt label=disable --ipc=host --cap-add=SYS_PTRACE --cap-add=NET_RAW --volume /run/udev:/run/udev:ro"
container_generate_entry=1
EOF

## ── ANDROID TOOLS ────────────────────────────────────────────────────────────
# adb, fastboot, etc.
dnf -y install android-tools

# Waydroid: Android container (binder is built into CachyOS kernel)
# NOTE: 'waydroid init' must be run on the live system — downloads Android image
dnf -y install waydroid

## ── SYSTEM TOOLS ─────────────────────────────────────────────────────────────
dnf -y install \
    flatpak-builder iotop sysstat parallel \
    thermald \
    lm_sensors irqbalance microcode_ctl \
    earlyoom

# scx-scheds: sched-ext userspace schedulers — not always in F44 main yet
dnf -y install scx-scheds || \
    echo "[warn] scx-scheds not available in repos, skipping — install manually if needed"

# Modern CLI replacements
dnf -y install \
    bat fd-find fzf jq \
    htop \
    fastfetch cowsay

# GitHub CLI + git-lfs (required by .gitconfig)
dnf -y install gh git-lfs

## ── INTEL IRIS XE ────────────────────────────────────────────────────────────
# VA-API hardware decode, Vulkan, mesa — no NVIDIA
dnf -y install \
    intel-media-driver libva libva-utils \
    mesa-dri-drivers mesa-vulkan-drivers vulkan-tools \
    intel-gpu-tools \
    libvpl libvpl-tools                  # Intel QSV (Video Processing Library)

## ── AUDIO / VIDEO ────────────────────────────────────────────────────────────
# Base ffmpeg stack + H264/H265/AV1 encode-decode
dnf -y install \
    ffmpeg ffmpeg-libs \
    x264-libs x265 libde265 \
    libdav1d libaom \
    lame \
    --allowerasing

# GStreamer full stack (needed by Firefox, Nautilus previews, GNOME apps)
# fedora-multimedia replaces gstreamer1-plugins-bad-free → gstreamer1-plugins-bad
dnf -y install \
    gstreamer1-plugins-good \
    gstreamer1-plugins-bad \
    gstreamer1-plugins-bad-freeworld \
    gstreamer1-plugins-ugly \
    gstreamer1-libav \
    gstreamer1-vaapi \
    gstreamer1-plugin-openh264 \
    --allowerasing --nobest

# HEIF/HEIC image support (iPhone photos, H.265-based)
dnf -y install libheif libheif-freeworld --allowerasing --nobest

# Mozilla OpenH264 (Firefox in-browser H264 decode)
dnf -y install mozilla-openh264

# DVD playback
dnf -y install libdvdread libdvdnav

# OBS
dnf -y install obs-studio obs-studio-plugin-x264

# Bluetooth hi-fi codecs: aptX already in pipewire-libs-extra (base image),
# libldac already installed as dep — both present, no explicit install needed

## ── FONTS ────────────────────────────────────────────────────────────────────
# Inter: clean humanist sans — warm feel, excellent screen legibility
dnf -y install rsms-inter-fonts

# Subpixel rendering + light hinting for Intel Iris Xe LCD
cat > /etc/fonts/local.conf << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <match target="font">
    <edit name="antialias"  mode="assign"><bool>true</bool></edit>
    <edit name="hinting"    mode="assign"><bool>true</bool></edit>
    <edit name="hintstyle"  mode="assign"><const>hintslight</const></edit>
    <edit name="rgba"       mode="assign"><const>rgb</const></edit>
    <edit name="lcdfilter"  mode="assign"><const>lcddefault</const></edit>
  </match>
</fontconfig>
EOF

## ── USER APPS ────────────────────────────────────────────────────────────────
dnf -y install nautilus kitty mpv gnome-terminal gnome-system-monitor yakuake

# Wine (RPM Fusion) — both 64 and 32-bit for legacy app compatibility
dnf -y install wine wine.i686

## ── WAYLAND SESSION TOOLS ───────────────────────────────────────────────────
# brightnessctl: keyboard brightness keys; playerctl: media keys
dnf -y install brightnessctl playerctl

## ── NAUTILUS OPEN-ANY-TERMINAL ───────────────────────────────────────────────
dnf install -y nautilus-open-any-terminal
glib-compile-schemas /usr/share/glib-2.0/schemas

# Set kitty as default terminal via dconf system-wide db (works without D-Bus)
mkdir -p /etc/dconf/db/local.d/
cat > /etc/dconf/db/local.d/01-nautilus-terminal << 'EOF'
[com/github/stunkymonkey/nautilus-open-any-terminal]
terminal='kitty'
EOF
dconf update

## ── KDE THEMES (downloaded from source, always latest) ──────────────────────
# Papirus: base icon theme — Nordic-darker overrides only folder icons
dnf -y install papirus-icon-theme

# Kvantum: Qt widget engine — reads KDE color scheme for warm palette
dnf -y install kvantum

# adw-gtk3: clean light GTK3/4 theme (no libadwaita required)
dnf -y install adw-gtk3-theme

# Ant-Kde: color scheme + LnF package only (aurorae not used — Breeze decoration active)
git clone --depth 1 https://github.com/EliverLara/Ant-Kde /tmp/Ant-Kde
install -dm755 /usr/share/color-schemes/
cp /tmp/Ant-Kde/color-schemes/Ant-Dark.colors /usr/share/color-schemes/
install -dm755 /usr/share/plasma/look-and-feel/
cp -r /tmp/Ant-Kde/plasma/look-and-feel/Ant-Dark /usr/share/plasma/look-and-feel/
rm -rf /tmp/Ant-Kde

# Carlos Warm color scheme — system-wide so all users can pick it in Settings
install -dm755 /usr/share/color-schemes/
cp /ctx/skel/.local/share/color-schemes/CarlosWarm.colors /usr/share/color-schemes/CarlosWarm.colors

# SDDM: Sugar-Dark theme with warm espresso palette
git clone --depth 1 https://github.com/MarianArlt/sddm-sugar-dark /tmp/sddm-sugar-dark
install -dm755 /usr/share/sddm/themes/
cp -r /tmp/sddm-sugar-dark /usr/share/sddm/themes/carlos-warm
rm -rf /tmp/sddm-sugar-dark

cat > /usr/share/sddm/themes/carlos-warm/theme.conf.user << 'EOF'
[General]
Background=/usr/share/wallpapers/Nordic-mountain-wallpaper.jpg
AccentColor=#B8753A
BackgroundColor=#2C1810
BodyColor=#E8D5B7
HeaderColor=#B8753A
HighlightColor=#B8753A
HighlightColorAlt=#7A4520
MainColor=#FAF6EF
OverrideLoginButtonTextColor=#FAF6EF
EOF

mkdir -p /etc/sddm.conf.d/
cat > /etc/sddm.conf.d/carlos.conf << 'EOF'
[Theme]
Current=carlos-warm
EOF

# GRUB: Vimix theme (same family as Vimix cursors already installed)
# After deployment, run once: sudo grub2-mkconfig -o /boot/grub2/grub.cfg
git clone --depth 1 https://github.com/vinceliuice/grub2-themes /tmp/grub2-themes
install -dm755 /usr/share/grub/themes/
cp -r /tmp/grub2-themes/themes/vimix /usr/share/grub/themes/vimix
rm -rf /tmp/grub2-themes

# Append GRUB_THEME only if not already set
grep -q '^GRUB_THEME=' /etc/default/grub 2>/dev/null || \
    echo 'GRUB_THEME="/usr/share/grub/themes/vimix/theme.txt"' >> /etc/default/grub
# Ensure terminal output is blank so theme renders fully
sed -i 's/^GRUB_TERMINAL_OUTPUT=.*//' /etc/default/grub 2>/dev/null || true

# Plymouth: warm Breeze theme (initrd rebuilt by bootc at compose time)
mkdir -p /etc/plymouth/
cat > /etc/plymouth/plymouthd.conf << 'EOF'
[Daemon]
Theme=breeze
ShowDelay=0
DeviceTimeout=8
EOF

# Nordic: folder icon overlay for KDE (inherits Papirus-Dark for app icons)
git clone --depth 1 https://github.com/EliverLara/Nordic /tmp/Nordic
install -dm755 /usr/share/icons/
cp -r /tmp/Nordic/kde/folders-darker/Nordic-darker /usr/share/icons/
gtk-update-icon-cache /usr/share/icons/Nordic-darker/ || true
rm -rf /tmp/Nordic

# Vimix cursors
git clone --depth 1 https://github.com/vinceliuice/Vimix-cursors /tmp/Vimix-cursors
bash /tmp/Vimix-cursors/install.sh -d /usr/share/icons
rm -rf /tmp/Vimix-cursors

## ── PACKAGE MANAGERS ─────────────────────────────────────────────────────────
# mise: per-project language version manager (node, python, go, ruby, java, …)
curl https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh

# uv: fast Python package + venv + version manager (replaces pip/pyenv/virtualenv)
UV_LATEST=$(curl -sf https://api.github.com/repos/astral-sh/uv/releases/latest | \
    python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])")
curl -fsSL "https://github.com/astral-sh/uv/releases/download/${UV_LATEST}/uv-x86_64-unknown-linux-musl.tar.gz" \
    | tar -xz -C /tmp
install -m755 /tmp/uv-x86_64-unknown-linux-musl/uv  /usr/local/bin/uv
install -m755 /tmp/uv-x86_64-unknown-linux-musl/uvx /usr/local/bin/uvx
rm -rf /tmp/uv-x86_64-unknown-linux-musl

## ── NIX: package manager (immutable-compatible) ──────────────────────────────
# /nix is empty in image (read-only layer); nix.mount bind-mounts /var/lib/nix
# over it at runtime so the Nix store lives on writable /var.
mkdir -p /nix

cat > /etc/tmpfiles.d/nix.conf << 'EOF'
d /var/lib/nix 0755 root root -
EOF

cat > /etc/systemd/system/nix.mount << 'EOF'
[Unit]
Description=Nix store (bind mount /var/lib/nix → /nix)
DefaultDependencies=no
After=var.mount
Before=local-fs.target

[Mount]
What=/var/lib/nix
Where=/nix
Type=none
Options=bind,x-systemd.requires-mounts-for=/var

[Install]
WantedBy=local-fs.target
EOF

# Run once after first login: sudo setup-nix
cat > /usr/local/bin/setup-nix << 'EOF'
#!/bin/bash
set -euo pipefail
echo "[setup-nix] Installing Nix (DeterminateSystems)..."
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install linux \
    --init systemd \
    --no-confirm \
    --extra-conf "trusted-users = root @wheel"
echo "[setup-nix] Done — open a new shell or run: . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
EOF
chmod +x /usr/local/bin/setup-nix
systemctl enable nix.mount

## ── ARCH DISTROBOX: AUR access via paru ──────────────────────────────────────
# Provides full AUR access via an Arch Linux container.
# Create with: distrobox assemble create --file /etc/distrobox/arch-aur.ini
# Use with:    distrobox enter arch-aur
mkdir -p /etc/distrobox
cat > /etc/distrobox/arch-aur.ini << 'EOF'
[arch-aur]
image=docker.io/archlinux:latest
init=false
pull=false
start_now=false
init_hooks=pacman-key --init && pacman-key --populate archlinux && pacman -Syu --noconfirm && pacman -S --noconfirm base-devel git sudo && useradd -m aurbuild && echo 'aurbuild ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/aurbuild && su - aurbuild -c 'git clone https://aur.archlinux.org/paru-bin.git /tmp/p && cd /tmp/p && makepkg -si --noconfirm && rm -rf /tmp/p' && userdel -r aurbuild && rm /etc/sudoers.d/aurbuild
EOF

## ── DESKTOP: KDE Plasma ──────────────────────────────────────────────────────
# KDE Plasma + SDDM already in kinoite-main base — no extra desktop install needed
# SDDM is already enabled; no display-manager override required

# kitty config
mkdir -p /etc/skel/.config/kitty/
cp -rf /ctx/dot_config/kitty/. /etc/skel/.config/kitty/

# Shell dotfiles, KDE config, themes, wallpaper
cp -rf /ctx/skel/. /etc/skel/

# Wallpaper also into system path so plasma skel config can reference it without user-home path
install -Dm644 /ctx/skel/.local/share/wallpapers/Nordic-mountain-wallpaper.jpg \
    /usr/share/wallpapers/Nordic-mountain-wallpaper.jpg

# oh-my-zsh + custom plugins — installed into skel so every new user gets it
git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git \
    /etc/skel/.oh-my-zsh
git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions \
    /etc/skel/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting \
    /etc/skel/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
git clone --depth 1 https://github.com/MichaelAquilina/zsh-autoswitch-virtualenv \
    /etc/skel/.oh-my-zsh/custom/plugins/autoswitch_virtualenv

# zsh as default shell for new users
useradd -D -s /bin/zsh

## ── JETBRAINS TOOLBOX ────────────────────────────────────────────────────────
# IDEs install to ~/.local/share/JetBrains — fully compatible with immutable OS
TOOLBOX_URL=$(curl -sf \
    "https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release" | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d['TBA'][0]['downloads']['linux']['link'])")
mkdir -p /opt/jetbrains-toolbox
curl -Lo /tmp/toolbox.tar.gz "$TOOLBOX_URL"
tar -xzf /tmp/toolbox.tar.gz -C /opt/jetbrains-toolbox --strip-components=1
rm /tmp/toolbox.tar.gz
ln -sf /opt/jetbrains-toolbox/jetbrains-toolbox /usr/local/bin/jetbrains-toolbox
cat > /usr/share/applications/jetbrains-toolbox.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=JetBrains Toolbox
Exec=/opt/jetbrains-toolbox/jetbrains-toolbox
Icon=/opt/jetbrains-toolbox/.install4j/jetbrains-toolbox.png
Categories=Development;IDE;
EOF

## ── KERNEL MODULES ───────────────────────────────────────────────────────────
# binder_linux is built into CachyOS kernel — no entry needed
cat > /etc/modules-load.d/virt-net.conf << 'EOF'
vhost_net
br_netfilter
tcp_bbr
EOF

## ── MODULE BLACKLIST ─────────────────────────────────────────────────────────
# iTCO_wdt: hardware watchdog driver (disabled via cmdline too, belt+suspenders)
# pcspkr / snd_pcsp: PC speaker beeper
cat > /etc/modprobe.d/blacklist.conf << 'EOF'
blacklist iTCO_wdt
blacklist iTCO_vendor_support
blacklist pcspkr
blacklist snd_pcsp
EOF

## ── INTEL IRIS XE: GuC/HuC + FBC ────────────────────────────────────────────
# enable_guc=3: GuC command submission + HuC video decode firmware offload
# enable_fbc=1: framebuffer compression — cuts VRAM bandwidth + NVMe writes
# fastboot=1:   skip display mode reset on boot (faster resume)
cat > /etc/modprobe.d/i915.conf << 'EOF'
options i915 enable_guc=3 enable_fbc=1 fastboot=1
EOF

## ── ZRAM: zstd compression ───────────────────────────────────────────────────
# 8GB is correct for 32GB RAM (swappiness=10 → barely touched)
# zstd: ~3x faster than lzo-rle, better compression ratio
cat > /etc/systemd/zram-generator.conf << 'EOF'
[zram0]
zram-size = min(ram / 4, 8192)
compression-algorithm = zstd
EOF

## ── JOURNALD: volatile (logs in RAM, zero NVMe writes) ─────────────────────
# Logs lost on reboot — fine for desktop; kdump handles kernel crashes
mkdir -p /etc/systemd/journald.conf.d/
cat > /etc/systemd/journald.conf.d/99-volatile.conf << 'EOF'
[Journal]
Storage=volatile
RuntimeMaxUse=128M
Compress=yes
EOF

## ── NATIVE COMPILE FLAGS (Raptor Lake i7-1360P) ─────────────────────────────
# Affects user-compiled code (cargo, gcc, make) — not pre-built RPMs
cat > /etc/profile.d/99-native-flags.sh << 'EOF'
export CFLAGS="-march=native -O2 -pipe"
export CXXFLAGS="-march=native -O2 -pipe"
export RUSTFLAGS="-C target-cpu=native"
export MAKEFLAGS="-j$(nproc)"
EOF

## ── PERFORMANCE TUNING ───────────────────────────────────────────────────────
cat > /etc/sysctl.d/99-perf.conf << 'EOF'
# Memory — i7-1360P, 32GB RAM, NVMe
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 20
vm.dirty_background_ratio = 5
vm.dirty_writeback_centisecs = 1500
vm.page-cluster = 0

# Suppress proactive memory compaction + watermark spike stalls
vm.compaction_proactiveness = 0
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125

# CPU scheduling — Intel Thread Director P/E core awareness (Raptor Lake)
kernel.sched_itmt_enabled = 1
kernel.nmi_watchdog = 0

# Finer time slices + faster wakeup for desktop responsiveness
kernel.sched_min_granularity_ns = 500000
kernel.sched_wakeup_granularity_ns = 50000
kernel.sched_migration_cost_ns = 250000

# Network — sized for WiFi 6 + Thunderbolt 4
kernel.unprivileged_userns_clone = 1
net.core.netdev_max_backlog = 16384
net.core.netdev_budget = 600
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
EOF

# BORE scheduler tuning — heavier penalty on CPU hogs, faster interactivity
cat > /etc/sysctl.d/99-bore.conf << 'EOF'
kernel.sched_bore = 1
kernel.sched_burst_cache_stop_count = 64
kernel.sched_burst_penalty_scale = 1280
kernel.sched_burst_smoothness_long = 1
kernel.sched_burst_smoothness_short = 0
EOF

# DAMON LRU sort — demotes cold pages proactively before memory pressure hits
cat > /etc/sysctl.d/99-damon.conf << 'EOF'
kernel.damon_lru_sort.enabled = 1
kernel.damon_lru_sort.wmarks.high = 500
kernel.damon_lru_sort.wmarks.mid = 400
kernel.damon_lru_sort.wmarks.low = 200
EOF

# udev: NVMe I/O scheduler — none is optimal for DRAM-less Crucial P3 Plus
cat > /etc/udev/rules.d/60-scheduler.rules << 'EOF'
ACTION=="add|change", KERNEL=="nvme[0-9]*n[0-9]*", ATTR{queue/scheduler}="none"
EOF

# Kernel cmdline
# transparent_hugepage=madvise: better for JVM/VMs than default 'always'
# Appended — bootc/dracut merges with base cmdline at compose time
echo " intel_pstate=active intel_iommu=on iommu=pt nowatchdog nvme_core.default_ps_max_latency_us=0 transparent_hugepage=madvise mitigations=off threadirqs nosoftlockup split_lock_detect=off zswap.enabled=0" \
    >> /etc/kernel/cmdline

# tuned: 'desktop' profile — interactive latency focus, not server throughput
echo "desktop" > /etc/tuned/active_profile

## ── SCX SCHEDULER ────────────────────────────────────────────────────────────
# scx_lavd: P/E core-aware scheduler — specifically tuned for asymmetric
# topologies like Raptor Lake (4P+8E). Outperforms BORE alone for interactive.
cat > /etc/sysconfig/scx << 'EOF'
SCX_SCHEDULER=scx_lavd
SCX_FLAGS=""
EOF

## ── PIPEWIRE: low-latency audio ──────────────────────────────────────────────
# quantum=512 @ 48kHz = ~10ms latency. min=32 for pro use, max=2048 for background.
mkdir -p /etc/pipewire/pipewire.conf.d/
cat > /etc/pipewire/pipewire.conf.d/99-latency.conf << 'EOF'
context.properties = {
    default.clock.rate        = 48000
    default.clock.quantum     = 512
    default.clock.min-quantum = 32
    default.clock.max-quantum = 2048
}
EOF

## ── EARLYOOM ─────────────────────────────────────────────────────────────────
# Kill at 4% free RAM / 10% free swap — fires before kernel OOM (less catastrophic)
# prefer browsers/electron; avoid core session processes
mkdir -p /etc/systemd/system/earlyoom.service.d/
cat > /etc/systemd/system/earlyoom.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=/usr/sbin/earlyoom -m 4 -s 10 \
    --avoid '(^|/)(Xorg|sshd|pipewire|wireplumber|systemd)$' \
    --prefer '(^|/)(chrome|chromium|electron|Discord|code|slack)$'
EOF

## ── SERVICES ─────────────────────────────────────────────────────────────────
systemctl enable podman.socket
systemctl enable thermald.service
systemctl enable libvirtd.service
systemctl enable irqbalance.service
systemctl enable fstrim.timer
systemctl enable scx.service
systemctl enable earlyoom.service
# Auto-fetch new bootc image in background daily (staged, applied on next reboot)
systemctl enable bootc-fetch-apply-updates.timer

## ── CLEANUP ──────────────────────────────────────────────────────────────────
dnf5 -y clean all
rm -rf /run/dnf /run/selinux-policy /var/lib/dnf
