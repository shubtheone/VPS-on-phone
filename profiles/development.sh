#!/data/data/com.termux/files/usr/bin/bash

#==============================================================================
#  Development Server Profile
#  Installs: Git, Python, Node.js, build tools, code editors
#==============================================================================

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
DIM='\033[2m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Package definitions: "package_name:description:apt_packages"
DEV_PACKAGES=(
    "git:Version control system:git git-lfs"
    "python:Python 3 programming language:python3 python3-pip python3-venv python3-dev"
    "nodejs:JavaScript runtime (LTS):nodejs npm"
    "build-tools:GCC, Make, CMake:build-essential gcc g++ make cmake autoconf automake"
    "vim:Vim text editor:vim"
    "neovim:Modern Neovim editor:neovim"
    "tmux:Terminal multiplexer:tmux screen"
    "htop:Process viewer and monitor:htop"
    "utilities:curl, wget, jq, tree:curl wget jq tree unzip zip"
    "search-tools:ripgrep, fd, fzf:ripgrep fd-find fzf"
)

#------------------------------------------------------------------------------
# Interactive Package Selection
#------------------------------------------------------------------------------

select_dev_packages() {
    local selected=()
    local total=${#DEV_PACKAGES[@]}
    
    # Initialize all as selected
    for ((i=0; i<total; i++)); do
        selected[$i]=1
    done
    
    local current=0
    local done=false
    
    # Check if we're in interactive mode
    if [[ ! -t 0 ]]; then
        # Non-interactive, install all
        INSTALL_PACKAGES=""
        for pkg_info in "${DEV_PACKAGES[@]}"; do
            local apt_pkgs="${pkg_info##*:}"
            INSTALL_PACKAGES="$INSTALL_PACKAGES $apt_pkgs"
        done
        return 0
    fi
    
    while ! $done; do
        clear
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}  🖥️  ${WHITE}Development Server - Package Selection${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC}  ${DIM}↑/↓: Navigate  SPACE: Toggle  A: All  N: None  ENTER: Install${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        for ((i=0; i<total; i++)); do
            local pkg_info="${DEV_PACKAGES[$i]}"
            IFS=':' read -r pkg_name pkg_desc pkg_apt <<< "$pkg_info"
            
            local checkbox=""
            if [[ ${selected[$i]} -eq 1 ]]; then
                checkbox="${GREEN}[✓]${NC}"
            else
                checkbox="[ ]"
            fi
            
            if [[ $i -eq $current ]]; then
                echo -e "  ${WHITE}▶${NC} $checkbox ${WHITE}$pkg_name${NC}"
                echo -e "       ${DIM}$pkg_desc${NC}"
                echo -e "       ${DIM}Packages: $pkg_apt${NC}"
            else
                echo -e "    $checkbox $pkg_name - ${DIM}$pkg_desc${NC}"
            fi
        done
        
        echo ""
        echo -e "${CYAN}─────────────────────────────────────────────────────────────────────${NC}"
        local count=0
        for s in "${selected[@]}"; do ((count += s)); done
        echo -e "  Selected: ${GREEN}$count${NC}/${total} | ${YELLOW}ENTER${NC}=Install | ${YELLOW}S${NC}=Skip Profile"
        
        read -rsn1 key
        
        # Handle arrow keys (they send escape sequences)
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 key
            case "$key" in
                '[A') ((current > 0)) && ((current--)) ;;
                '[B') ((current < total-1)) && ((current++)) ;;
            esac
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
    
    # Build install list
    INSTALL_PACKAGES=""
    SKIP_PROFILE=false
    for ((i=0; i<total; i++)); do
        if [[ ${selected[$i]} -eq 1 ]]; then
            local pkg_info="${DEV_PACKAGES[$i]}"
            local apt_pkgs="${pkg_info##*:}"
            INSTALL_PACKAGES="$INSTALL_PACKAGES $apt_pkgs"
        fi
    done
}

#------------------------------------------------------------------------------
# Installation
#------------------------------------------------------------------------------

install_packages() {
    if [[ -z "$INSTALL_PACKAGES" ]]; then
        echo -e "${YELLOW}No packages selected, skipping Development profile${NC}"
        return 0
    fi
    
    echo -e "${CYAN}Installing Development packages...${NC}"
    echo -e "${DIM}Packages: $INSTALL_PACKAGES${NC}"
    echo ""
    
    # Create installation script for Ubuntu
    cat > "$HOME/.vps-on-phone/install-dev.sh" << INSTALL_SCRIPT
#!/bin/bash
set -e

echo "Updating package lists..."
apt update

echo "Installing selected packages..."
apt install -y $INSTALL_PACKAGES

# Install Node.js from NodeSource if nodejs was selected
if command -v node &> /dev/null; then
    echo "Node.js already installed"
elif echo "$INSTALL_PACKAGES" | grep -q "nodejs"; then
    echo "Setting up Node.js LTS..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt install -y nodejs
fi

# Install common dev tools via pip if python was selected
if echo "$INSTALL_PACKAGES" | grep -q "python3-pip"; then
    echo "Installing Python dev tools..."
    pip3 install --break-system-packages virtualenv black flake8 ipython 2>/dev/null || \
    pip3 install virtualenv black flake8 ipython
fi

# Install common npm packages if nodejs was selected
if command -v npm &> /dev/null; then
    echo "Installing global npm packages..."
    npm install -g yarn typescript ts-node nodemon pm2 2>/dev/null || true
fi

echo ""
echo "✓ Development packages installed!"
INSTALL_SCRIPT

    chmod +x "$HOME/.vps-on-phone/install-dev.sh"
    
    # Run in Ubuntu
    proot-distro login ubuntu -- bash /data/data/com.termux/files/home/.vps-on-phone/install-dev.sh
    
    echo -e "${GREEN}✓ Development Server profile complete!${NC}"
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

main() {
    echo -e "📦 ${WHITE}Development Server Profile${NC}"
    
    # Interactive selection
    select_dev_packages
    
    if [[ "$SKIP_PROFILE" == "true" ]]; then
        echo -e "${YELLOW}Skipping Development profile${NC}"
        return 0
    fi
    
    # Install selected packages
    install_packages
}

main "$@"
