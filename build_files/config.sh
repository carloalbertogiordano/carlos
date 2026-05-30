#!/bin/bash

set -ouex pipefail

## ── KDE THEMES ───────────────────────────────────────────────────────────────
dnf -y install papirus-icon-theme kvantum adw-gtk3-theme

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

# GRUB: Vimix theme
git clone --depth 1 https://github.com/vinceliuice/grub2-themes /tmp/grub2-themes
install -dm755 /usr/share/grub/themes/
[ -f /etc/default/grub ] || touch /etc/default/grub
bash /tmp/grub2-themes/install.sh --theme vimix --screen 1080p
rm -rf /tmp/grub2-themes

grep -q '^GRUB_THEME=' /etc/default/grub 2>/dev/null || \
    echo 'GRUB_THEME="/usr/share/grub/themes/vimix/theme.txt"' >> /etc/default/grub
sed -i 's/^GRUB_TERMINAL_OUTPUT=.*//' /etc/default/grub 2>/dev/null || true

# Plymouth
mkdir -p /etc/plymouth/
cat > /etc/plymouth/plymouthd.conf << 'EOF'
[Daemon]
Theme=breeze
ShowDelay=0
DeviceTimeout=8
EOF

# Nordic folder icons
git clone --depth 1 https://github.com/EliverLara/Nordic /tmp/Nordic
install -dm755 /usr/share/icons/
cp -r /tmp/Nordic/kde/folders/Nordic-darker /usr/share/icons/
gtk-update-icon-cache /usr/share/icons/Nordic-darker/ || true
rm -rf /tmp/Nordic

# Vimix cursors
git clone --depth 1 https://github.com/vinceliuice/Vimix-cursors /tmp/Vimix-cursors
(cd /tmp/Vimix-cursors && bash install.sh)
rm -rf /tmp/Vimix-cursors

## ── PACKAGE MANAGERS ─────────────────────────────────────────────────────────
curl https://mise.run | MISE_INSTALL_PATH=/usr/bin/mise sh

dnf -y install python3-pip
pip3 install --prefix=/usr uv

## ── NIX ──────────────────────────────────────────────────────────────────────
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

cat > /usr/bin/setup-nix << 'EOF'
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
chmod +x /usr/bin/setup-nix
systemctl enable nix.mount

## ── ARCH DISTROBOX ───────────────────────────────────────────────────────────
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
mkdir -p /etc/skel/.config/kitty/
cp -rf /ctx/dot_config/kitty/. /etc/skel/.config/kitty/

cp -rf /ctx/skel/. /etc/skel/

install -Dm644 /ctx/skel/.local/share/wallpapers/Nordic-mountain-wallpaper.jpg \
    /usr/share/wallpapers/Nordic-mountain-wallpaper.jpg

git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git \
    /etc/skel/.oh-my-zsh
git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions \
    /etc/skel/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting \
    /etc/skel/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
git clone --depth 1 https://github.com/MichaelAquilina/zsh-autoswitch-virtualenv \
    /etc/skel/.oh-my-zsh/custom/plugins/autoswitch_virtualenv

useradd -D -s /bin/zsh

## ── JETBRAINS TOOLBOX ────────────────────────────────────────────────────────
TOOLBOX_URL=$(curl -sf \
    "https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release" | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d['TBA'][0]['downloads']['linux']['link'])")
install -dm755 /usr/share/jetbrains-toolbox
curl -Lo /tmp/toolbox.tar.gz "$TOOLBOX_URL"
tar -xzf /tmp/toolbox.tar.gz -C /usr/share/jetbrains-toolbox --strip-components=1
rm /tmp/toolbox.tar.gz
ln -sf /usr/share/jetbrains-toolbox/jetbrains-toolbox /usr/bin/jetbrains-toolbox
cat > /usr/share/applications/jetbrains-toolbox.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=JetBrains Toolbox
Exec=/usr/share/jetbrains-toolbox/jetbrains-toolbox
Icon=/usr/share/jetbrains-toolbox/.install4j/jetbrains-toolbox.png
Categories=Development;IDE;
EOF

## ── KERNEL MODULES ───────────────────────────────────────────────────────────
cat > /etc/modules-load.d/virt-net.conf << 'EOF'
vhost_net
br_netfilter
tcp_bbr
EOF

cat > /etc/modprobe.d/blacklist.conf << 'EOF'
blacklist iTCO_wdt
blacklist iTCO_vendor_support
blacklist pcspkr
blacklist snd_pcsp
EOF

cat > /etc/modprobe.d/i915.conf << 'EOF'
options i915 enable_guc=3 enable_fbc=1 fastboot=1
EOF

## ── ZRAM ─────────────────────────────────────────────────────────────────────
cat > /etc/systemd/zram-generator.conf << 'EOF'
[zram0]
zram-size = min(ram / 4, 8192)
compression-algorithm = zstd
EOF

## ── JOURNALD ─────────────────────────────────────────────────────────────────
mkdir -p /etc/systemd/journald.conf.d/
cat > /etc/systemd/journald.conf.d/99-volatile.conf << 'EOF'
[Journal]
Storage=volatile
RuntimeMaxUse=128M
Compress=yes
EOF

## ── NATIVE COMPILE FLAGS ─────────────────────────────────────────────────────
cat > /etc/profile.d/99-native-flags.sh << 'EOF'
export CFLAGS="-march=native -O2 -pipe"
export CXXFLAGS="-march=native -O2 -pipe"
export RUSTFLAGS="-C target-cpu=native"
export MAKEFLAGS="-j$(nproc)"
EOF

## ── PERFORMANCE TUNING ───────────────────────────────────────────────────────
cat > /etc/sysctl.d/99-perf.conf << 'EOF'
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 20
vm.dirty_background_ratio = 5
vm.dirty_writeback_centisecs = 1500
vm.page-cluster = 0
vm.compaction_proactiveness = 0
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
kernel.sched_itmt_enabled = 1
kernel.nmi_watchdog = 0
kernel.sched_min_granularity_ns = 500000
kernel.sched_wakeup_granularity_ns = 50000
kernel.sched_migration_cost_ns = 250000
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

cat > /etc/sysctl.d/99-bore.conf << 'EOF'
kernel.sched_bore = 1
kernel.sched_burst_cache_stop_count = 64
kernel.sched_burst_penalty_scale = 1280
kernel.sched_burst_smoothness_long = 1
kernel.sched_burst_smoothness_short = 0
EOF

cat > /etc/sysctl.d/99-damon.conf << 'EOF'
kernel.damon_lru_sort.enabled = 1
kernel.damon_lru_sort.wmarks.high = 500
kernel.damon_lru_sort.wmarks.mid = 400
kernel.damon_lru_sort.wmarks.low = 200
EOF

cat > /etc/udev/rules.d/60-scheduler.rules << 'EOF'
ACTION=="add|change", KERNEL=="nvme[0-9]*n[0-9]*", ATTR{queue/scheduler}="none"
EOF

mkdir -p /etc/kernel/
echo " intel_pstate=active intel_iommu=on iommu=pt nowatchdog nvme_core.default_ps_max_latency_us=0 transparent_hugepage=madvise mitigations=off threadirqs nosoftlockup split_lock_detect=off zswap.enabled=0" \
    >> /etc/kernel/cmdline

mkdir -p /etc/tuned/
echo "desktop" > /etc/tuned/active_profile

## ── SCX SCHEDULER ────────────────────────────────────────────────────────────
mkdir -p /etc/sysconfig/
cat > /etc/sysconfig/scx << 'EOF'
SCX_SCHEDULER=scx_lavd
SCX_FLAGS=""
EOF

## ── PIPEWIRE ─────────────────────────────────────────────────────────────────
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
systemctl enable scx.service 2>/dev/null || true
systemctl enable earlyoom.service
systemctl enable bootc-fetch-apply-updates.timer

## ── CLEANUP ──────────────────────────────────────────────────────────────────
dnf -y clean all
rm -rf /run/dnf /run/selinux-policy /var/lib/dnf
