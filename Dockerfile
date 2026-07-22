# Isolated Development Environment with Rust Nightly
FROM docker.io/debian:bookworm-slim

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
    sudo \
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
    xterm \
    && rm -rf /var/lib/apt/lists/*

# Install copilot - doing as root for global installation to avoid annoyances
RUN npm install -g @github/copilot

# Create a non-root user for development
RUN useradd -m -s /bin/bash -G sudo devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to devuser
USER devuser
WORKDIR /home/devuser

# Install Rust nightly via rustup
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain nightly
ENV PATH="/home/devuser/.cargo/bin:${PATH}"

# Verify installations
RUN rustc --version && cargo --version && gcc --version

# Install cargo flamegraph and uv
RUN cargo install --locked flamegraph uv cargo-samply samply ripgrep

# Install claude, this can be done without root
RUN curl -fsSL https://claude.ai/install.sh | bash

# Install Oh My Zsh for a better shell experience
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" -- --unattended -p git

WORKDIR /home/devuser

# Copy our login.sh script to the container
COPY --chown=devuser:devuser scripts/login.sh /home/devuser/login.sh

RUN chmod +x /home/devuser/login.sh && echo "source /home/devuser/login.sh" >> /home/devuser/.zshrc

# Keep container running
CMD sleep infinity
