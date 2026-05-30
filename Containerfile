# Packages context — only changes when packages.sh changes
FROM scratch AS ctx-packages
COPY build_files/packages.sh /

# Full config context — skel, themes, dotfiles, scripts
FROM scratch AS ctx-config
COPY build_files/ /

# Base Image: Universal Blue KDE spin (KDE Plasma + SDDM pre-installed)
FROM ghcr.io/ublue-os/kinoite-main:44

# Homebrew
COPY --from=ghcr.io/ublue-os/brew:latest /system_files /
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /usr/bin/systemctl preset brew-setup.service && \
    /usr/bin/systemctl preset brew-update.timer && \
    /usr/bin/systemctl preset brew-upgrade.timer

# Layer 1: System packages, kernel, drivers, codecs, apps
# Cached as long as packages.sh doesn't change — ~20-25 min saved per ricing commit
RUN --mount=type=bind,from=ctx-packages,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/packages.sh

# Layer 2: Themes, tools, skel, config, services
# Rebuilds on skel/dotfile/theme changes — fast because packages layer is cached
RUN --mount=type=bind,from=ctx-config,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/config.sh

# Flatpaks — separate layer so CI can cache it independently
RUN --mount=type=bind,from=ctx-config,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    /ctx/install-flatpaks.sh

### LINTING
RUN bootc container lint
