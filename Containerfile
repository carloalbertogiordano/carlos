# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image: clean Fedora 44, no NVIDIA bloat (machine has Intel Iris Xe only)
FROM ghcr.io/ublue-os/base-main:44

## Other possible base images:
# FROM ghcr.io/ublue-os/base-main:latest
# FROM quay.io/fedora/fedora-bootc:44

### [IM]MUTABLE /opt
## JetBrains Toolbox writes to ~/.local/share/JetBrains (user home) — no /opt needed.
## Uncomment below if you want /opt truly immutable and managed by the package manager.
# RUN rm /opt && mkdir /opt

# Homebrew
COPY --from=ghcr.io/ublue-os/brew:latest /system_files /
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /usr/bin/systemctl preset brew-setup.service && \
    /usr/bin/systemctl preset brew-update.timer && \
    /usr/bin/systemctl preset brew-upgrade.timer

# System packages, kernel, desktop, performance tuning
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

# Flatpaks — separate layer so CI can cache it independently of system changes
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    /ctx/install-flatpaks.sh

### LINTING
RUN bootc container lint
