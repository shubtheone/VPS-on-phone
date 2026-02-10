#!/data/data/com.termux/files/usr/bin/bash

#==============================================================================
#  File Sharing Profile
#  Installs: SFTP, Web file manager, rsync
#==============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
DIM='\033[2m'

# Package definitions
FILE_PACKAGES=(
    "sftp:SFTP server for secure file transfer:openssh-sftp-server"
    "rsync:Fast incremental file transfer:rsync"
    "rclone:Cloud storage sync (Google Drive, S3, etc.):rclone"
    "archive-tools:ZIP, 7z, tar support:zip unzip p7zip-full tar gzip bzip2 xz-utils"
    "filebrowser:Web-based file manager with UI:SPECIAL_FILEBROWSER"
    "aria2:Download manager:aria2"
)

select_file_packages() {
    local selected=()
    local total=${#FILE_PACKAGES[@]}
    
    for ((i=0; i<total; i++)); do selected[$i]=1; done
    
    local current=0
    local done=false
    
    if [[ ! -t 0 ]]; then
        INSTALL_PACKAGES=""
        INSTALL_FILEBROWSER=true
        for pkg_info in "${FILE_PACKAGES[@]}"; do
            local pkgs="${pkg_info##*:}"
            [[ "$pkgs" != "SPECIAL_FILEBROWSER" ]] && INSTALL_PACKAGES="$INSTALL_PACKAGES $pkgs"
        done
        return 0
    fi
    
    while ! $done; do
        clear
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}  📁 ${WHITE}File Sharing - Package Selection${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC}  ${DIM}↑/↓: Navigate  SPACE: Toggle  A: All  N: None  ENTER: Install${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        for ((i=0; i<total; i++)); do
            IFS=':' read -r pkg_name pkg_desc pkg_apt <<< "${FILE_PACKAGES[$i]}"
            local checkbox=$([[ ${selected[$i]} -eq 1 ]] && echo -e "${GREEN}[✓]${NC}" || echo "[ ]")
            
            if [[ $i -eq $current ]]; then
                echo -e "  ${WHITE}▶${NC} $checkbox ${WHITE}$pkg_name${NC}"
                echo -e "       ${DIM}$pkg_desc${NC}"
            else
                echo -e "    $checkbox $pkg_name - ${DIM}$pkg_desc${NC}"
            fi
        done
        
        echo ""
        local count=0; for s in "${selected[@]}"; do ((count += s)); done
        echo -e "  Selected: ${GREEN}$count${NC}/${total} | ${YELLOW}ENTER${NC}=Install | ${YELLOW}S${NC}=Skip"
        
        read -rsn1 key
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 key
            [[ "$key" == '[A' ]] && ((current > 0)) && ((current--))
            [[ "$key" == '[B' ]] && ((current < total-1)) && ((current++))
        else
            case "$key" in
                k) ((current > 0)) && ((current--)) ;;
                j) ((current < total-1)) && ((current++)) ;;
                ' ') selected[$current]=$((1 - ${selected[$current]})) ;;
                a|A) for ((i=0; i<total; i++)); do selected[$i]=1; done ;;
                n|N) for ((i=0; i<total; i++)); do selected[$i]=0; done ;;
                s|S) INSTALL_PACKAGES=""; SKIP_PROFILE=true; return 0 ;;
                '') done=true ;;
            esac
        fi
    done
    
    INSTALL_PACKAGES=""
    INSTALL_FILEBROWSER=false
    SKIP_PROFILE=false
    
    for ((i=0; i<total; i++)); do
        if [[ ${selected[$i]} -eq 1 ]]; then
            local pkg_apt="${FILE_PACKAGES[$i]##*:}"
            if [[ "$pkg_apt" == "SPECIAL_FILEBROWSER" ]]; then
                INSTALL_FILEBROWSER=true
            else
                INSTALL_PACKAGES="$INSTALL_PACKAGES $pkg_apt"
            fi
        fi
    done
}

install_packages() {
    [[ -z "$INSTALL_PACKAGES" && "$INSTALL_FILEBROWSER" != "true" ]] && { 
        echo -e "${YELLOW}Skipping File Sharing${NC}"; return 0; 
    }
    
    echo -e "${CYAN}Installing File Sharing packages...${NC}"
    
    cat > "$HOME/.vps-on-phone/install-file.sh" << INSTALL_SCRIPT
#!/bin/bash
set -e

apt update

# Install apt packages
if [ -n "$INSTALL_PACKAGES" ]; then
    apt install -y $INSTALL_PACKAGES
fi

# Install FileBrowser if selected
if [ "$INSTALL_FILEBROWSER" = "true" ]; then
    echo "Installing FileBrowser..."
    ARCH=\$(dpkg --print-architecture)
    if [[ "\$ARCH" == "arm64" ]] || [[ "\$ARCH" == "aarch64" ]]; then
        FB_ARCH="linux-arm64"
    else
        FB_ARCH="linux-armv7"
    fi
    
    curl -fsSL "https://github.com/filebrowser/filebrowser/releases/latest/download/\${FB_ARCH}-filebrowser.tar.gz" | tar xz -C /usr/local/bin
    
    mkdir -p /var/lib/filebrowser
    mkdir -p /srv/files/shared
    mkdir -p /srv/files/uploads
    
    filebrowser config init --database /var/lib/filebrowser/filebrowser.db
    filebrowser config set --database /var/lib/filebrowser/filebrowser.db --address 0.0.0.0 --port 8080 --root /srv/files --baseURL /filebrowser
    filebrowser users add admin "admin12345678" --database /var/lib/filebrowser/filebrowser.db --perm.admin
    
    echo ""
    echo "✓ FileBrowser installed successfully!"
    echo ""
    echo "  📁 File Manager is integrated in the Dashboard"
    echo "  🌐 Dashboard URL: http://localhost:5000"
    echo "  📋 Click the 'File Manager' tab to access files"
    echo ""
    echo "  Default Login Credentials:"
    echo "    Username: admin"
    echo "    Password: admin12345678"
    echo ""
    echo "  ⚠️  Change the password after first login!"
fi

echo "✓ File Sharing packages installed!"
INSTALL_SCRIPT

    chmod +x "$HOME/.vps-on-phone/install-file.sh"
    proot-distro login ubuntu -- bash /data/data/com.termux/files/home/.vps-on-phone/install-file.sh
    
    echo -e "${GREEN}✓ File Sharing profile complete!${NC}"
}

main() {
    echo -e "📦 ${WHITE}File Sharing Profile${NC}"
    select_file_packages
    [[ "$SKIP_PROFILE" == "true" ]] && { echo -e "${YELLOW}Skipping File Sharing${NC}"; return 0; }
    install_packages
}

main "$@"
