#!/data/data/com.termux/files/usr/bin/bash

#==============================================================================
#  File Sharing Profile
#  Installs: SFTP, Web file manager, rsync
#==============================================================================

echo "📦 Installing File Sharing profile..."

proot-distro login ubuntu -- bash << 'FILE_INSTALL'
#!/bin/bash
set -e

echo "Installing file sharing packages..."

apt update

# File transfer tools
apt install -y \
    openssh-sftp-server \
    rsync \
    rclone \
    lftp \
    curl \
    wget \
    aria2

# Archive tools
apt install -y \
    zip \
    unzip \
    p7zip-full \
    tar \
    gzip \
    bzip2 \
    xz-utils

# File browser (web-based file manager)
apt install -y python3 python3-pip

# Install FileBrowser (web-based file manager)
echo "Installing FileBrowser..."
ARCH=$(dpkg --print-architecture)
if [[ "$ARCH" == "arm64" ]] || [[ "$ARCH" == "aarch64" ]]; then
    FB_ARCH="linux-arm64"
else
    FB_ARCH="linux-armv7"
fi

curl -fsSL "https://github.com/filebrowser/filebrowser/releases/latest/download/${FB_ARCH}-filebrowser.tar.gz" | tar xz -C /usr/local/bin

# Create FileBrowser directory
mkdir -p /var/lib/filebrowser
mkdir -p /srv/files

# Initialize FileBrowser database
filebrowser config init --database /var/lib/filebrowser/filebrowser.db
filebrowser config set --database /var/lib/filebrowser/filebrowser.db --address 0.0.0.0 --port 8080 --root /srv/files
filebrowser users add admin admin --database /var/lib/filebrowser/filebrowser.db --perm.admin

# Create shared directory
mkdir -p /srv/files/shared
mkdir -p /srv/files/uploads
chmod 755 /srv/files

echo "✓ File sharing profile installed!"
echo "  SFTP: Enabled (via SSH)"
echo "  FileBrowser: http://localhost:8080 (admin/admin)"
echo "  Shared files: /srv/files"
FILE_INSTALL

echo "✓ File Sharing profile complete!"
