# Isolated Development Environment with Rust Nightly
#
# Two targets:
#   base    - cross-platform (Windows/WSL, macOS, Linux) headless dev environment
#   desktop - base + GUI libraries for running X11/Electron apps via WSLg
FROM docker.io/debian:bookworm-slim AS base

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Initialize apt and add github cli keyring
RUN apt-get update && apt install wget -y \
    && mkdir -p -m 755 /etc/apt/keyrings \
    && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && cat $out | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && mkdir -p -m 755 /etc/apt/sources.list.d \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt update

# Install essential development tools
RUN apt-get install -y \
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    git \
    gh \
    curl \
    wget \
    vim \
    ca-certificates \
    pkg-config \
    libssl-dev \
    linux-perf \
    nodejs \
    npm \
    python3 \
    python3-pip \
    zsh \
    unzip \
    rclone \
    ripgrep \
    && rm -rf /var/lib/apt/lists/*

# Install copilot - doing as root for global installation to avoid annoyances
RUN npm install -g @github/copilot

# Create a non-root user for development. Deliberately no sudo: the container
# is meant to be locked down so agents cannot change global/admin state.
RUN useradd -m -s /bin/bash devuser

# Switch to devuser
USER devuser
WORKDIR /home/devuser

ENV PATH="/home/devuser/.cargo/bin:/home/devuser/.local/bin:${PATH}"
# Private runtime dir (sockets etc.), created at container start on the /tmp tmpfs
ENV XDG_RUNTIME_DIR=/tmp/runtime-devuser

# Install Rust nightly via rustup
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain nightly

# Verify installations
RUN rustc --version && cargo --version && gcc --version

# Install cargo tools as prebuilt binaries via cargo-binstall rather than compiling
# from source (falls back to compiling only if no prebuilt binary is available)
RUN curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash \
    && cargo binstall -y --locked flamegraph samply cargo-samply

# Install uv from its prebuilt release
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh

# Install claude, this can be done without root
RUN curl -fsSL https://claude.ai/install.sh | bash

# Install Oh My Zsh for a better shell experience
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" -- --unattended -p git

WORKDIR /home/devuser

# Copy our login.sh script to the container
COPY --chown=devuser:devuser scripts/login.sh /home/devuser/login.sh

RUN chmod +x /home/devuser/login.sh && echo "source /home/devuser/login.sh" >> /home/devuser/.zshrc

# Start-up script: creates the runtime dir (plus D-Bus/keyring in the desktop image), then keeps
# the container running
COPY scripts/container-init.sh /usr/local/bin/container-init
CMD ["sh", "/usr/local/bin/container-init"]


FROM base AS desktop

USER root

# GUI libraries needed by X11 / Electron apps (e.g. Claude Desktop), plus xterm
# for a quick "does X11 work" check
RUN apt-get update && apt-get install -y \
    xterm \
    xdg-utils \
    fonts-liberation \
    libgtk-3-0 \
    libnss3 \
    libasound2 \
    libgbm1 \
    libdrm2 \
    libxss1 \
    libxtst6 \
    libxshmfence1 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libxkbcommon0 \
    libatk-bridge2.0-0 \
    libatspi2.0-0 \
    libcups2 \
    libsecret-1-0 \
    libnotify4 \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Desktop (Linux beta) from Anthropic's apt repository, verifying the signing key's
# fingerprint. Recommended packages (QEMU/OVMF for Cowork) are skipped as there's no KVM in the
# container; gnome-keyring + dbus-x11 are added so the sign-in can be saved.
# See https://code.claude.com/docs/en/desktop-linux
RUN curl -fsSLo /usr/share/keyrings/claude-desktop-archive-keyring.asc https://downloads.claude.ai/claude-desktop/key.asc \
    && gpg --show-keys --with-colons /usr/share/keyrings/claude-desktop-archive-keyring.asc | grep -q '^fpr:*31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE:' \
    && echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] https://downloads.claude.ai/claude-desktop/apt/stable stable main" > /etc/apt/sources.list.d/claude-desktop.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends claude-desktop gnome-keyring dbus-x11 \
    && rm -rf /var/lib/apt/lists/*

# Launcher that adds the flags Claude Desktop needs in the container (shadows /usr/bin/claude-desktop)
COPY scripts/claude-desktop.sh /usr/local/bin/claude-desktop
RUN chmod 755 /usr/local/bin/claude-desktop

# Shared D-Bus session bus, started by container-init at the standard per-user location
ENV DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/runtime-devuser/bus

USER devuser
