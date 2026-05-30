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

mkdir -p /etc/distrobox/
cat > /etc/distrobox/distrobox.conf << 'EOF'
container_additional_flags="--device /dev/dri --device /dev/fuse --security-opt label=disable --ipc=host --cap-add=SYS_PTRACE --cap-add=NET_RAW --volume /run/udev:/run/udev:ro"
container_generate_entry=1
EOF

## ── ANDROID TOOLS ────────────────────────────────────────────────────────────
dnf -y install android-tools
dnf -y install waydroid

## ── SYSTEM TOOLS ─────────────────────────────────────────────────────────────
dnf -y install \
    flatpak-builder iotop sysstat parallel \
    thermald \
    lm_sensors irqbalance microcode_ctl \
    earlyoom

dnf -y install scx-scheds || \
    echo "[warn] scx-scheds not available in repos, skipping"

dnf -y install \
    bat fd-find fzf jq \
    htop \
    fastfetch cowsay

dnf -y install gh git-lfs

## ── INTEL IRIS XE ────────────────────────────────────────────────────────────
dnf -y install \
    intel-media-driver libva libva-utils \
    mesa-dri-drivers mesa-vulkan-drivers vulkan-tools \
    intel-gpu-tools \
    libvpl libvpl-tools

## ── AUDIO / VIDEO ────────────────────────────────────────────────────────────
dnf -y install \
    ffmpeg ffmpeg-libs \
    x264-libs x265 libde265 \
    libdav1d libaom \
    lame \
    --allowerasing

dnf -y install \
    gstreamer1-plugins-good \
    gstreamer1-plugins-bad \
    gstreamer1-plugins-bad-freeworld \
    gstreamer1-plugins-ugly \
    gstreamer1-libav \
    gstreamer1-vaapi \
    gstreamer1-plugin-openh264 \
    --allowerasing --nobest

dnf -y install libheif libheif-freeworld --allowerasing --nobest
dnf -y install mozilla-openh264
dnf -y install libdvdread libdvdnav
dnf -y install obs-studio obs-studio-plugin-x264

## ── FONTS ────────────────────────────────────────────────────────────────────
dnf -y install rsms-inter-fonts

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
dnf -y install wine wine.i686
dnf -y install brightnessctl playerctl

## ── NAUTILUS OPEN-ANY-TERMINAL ───────────────────────────────────────────────
dnf install -y nautilus-open-any-terminal
glib-compile-schemas /usr/share/glib-2.0/schemas

mkdir -p /etc/dconf/db/local.d/
cat > /etc/dconf/db/local.d/01-nautilus-terminal << 'EOF'
[com/github/stunkymonkey/nautilus-open-any-terminal]
terminal='kitty'
EOF
dconf update

## ── CLEANUP packages layer ───────────────────────────────────────────────────
dnf -y clean all
