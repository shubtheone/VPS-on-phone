#!/data/data/com.termux/files/usr/bin/bash

#==============================================================================
#  Development Server Profile
#  Installs: Git, Python, Node.js, build tools, code editors
#==============================================================================

echo "📦 Installing Development Server profile..."

proot-distro login ubuntu -- bash << 'DEV_INSTALL'
#!/bin/bash
set -e

echo "Installing development packages..."

apt update

# Core development tools
apt install -y \
    git \
    git-lfs \
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    autoconf \
    automake \
    pkg-config

# Python development
apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    ipython3

# Node.js (using NodeSource)
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt install -y nodejs

# Additional tools
apt install -y \
    neovim \
    vim \
    nano \
    tmux \
    screen \
    htop \
    tree \
    jq \
    ripgrep \
    fd-find \
    fzf \
    unzip \
    zip \
    gzip \
    tar

# Install common Python packages globally
pip3 install --break-system-packages \
    virtualenv \
    pipenv \
    poetry \
    black \
    flake8 \
    pylint \
    ipython \
    jupyter

# Install common npm packages globally
npm install -g \
    yarn \
    pnpm \
    nodemon \
    pm2 \
    typescript \
    ts-node \
    eslint \
    prettier

echo "✓ Development profile installed!"
DEV_INSTALL

echo "✓ Development Server profile complete!"
