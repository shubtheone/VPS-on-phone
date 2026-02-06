#!/data/data/com.termux/files/usr/bin/bash

#==============================================================================
#  Interactive Package Selector
#  Allows users to select individual packages within each profile
#==============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
DIM='\033[2m'

DATA_DIR="$HOME/.vps-on-phone"

#------------------------------------------------------------------------------
# Interactive Selection Menu
#------------------------------------------------------------------------------

# Usage: select_packages "Category Name" "pkg1:Desc1" "pkg2:Desc2" ...
# Returns selected packages in SELECTED_PACKAGES variable
select_packages() {
    local category="$1"
    shift
    local packages=("$@")
    local total=${#packages[@]}
    local selected=()
    
    # Initialize all as selected
    for ((i=0; i<total; i++)); do
        selected[$i]=1
    done
    
    local current=0
    local done=false
    
    while ! $done; do
        clear
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}  ${WHITE}📦 Package Selection: ${YELLOW}$category${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC}  ${DIM}Use arrow keys to navigate, SPACE to toggle, ENTER to confirm${NC}"
        echo -e "${CYAN}║${NC}  ${DIM}Press 'a' to select all, 'n' to select none, 's' to skip all${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        for ((i=0; i<total; i++)); do
            local pkg_info="${packages[$i]}"
            local pkg_name="${pkg_info%%:*}"
            local pkg_desc="${pkg_info#*:}"
            
            local checkbox=""
            if [[ ${selected[$i]} -eq 1 ]]; then
                checkbox="${GREEN}[✓]${NC}"
            else
                checkbox="${RED}[ ]${NC}"
            fi
            
            if [[ $i -eq $current ]]; then
                echo -e "  ${WHITE}▶${NC} $checkbox ${WHITE}$pkg_name${NC}"
                echo -e "       ${DIM}$pkg_desc${NC}"
            else
                echo -e "    $checkbox $pkg_name"
                echo -e "       ${DIM}$pkg_desc${NC}"
            fi
        done
        
        echo ""
        echo -e "${CYAN}─────────────────────────────────────────────────────────────────${NC}"
        
        # Count selected
        local count=0
        for s in "${selected[@]}"; do
            ((count += s))
        done
        echo -e "  ${WHITE}Selected: ${GREEN}$count${NC} / ${total} packages"
        echo ""
        echo -e "  ${YELLOW}[ENTER]${NC} Confirm  ${YELLOW}[SPACE]${NC} Toggle  ${YELLOW}[a]${NC} All  ${YELLOW}[n]${NC} None  ${YELLOW}[s]${NC} Skip"
        
        # Read single key
        read -rsn1 key
        
        case "$key" in
            A|k) # Up arrow or k
                ((current--))
                [[ $current -lt 0 ]] && current=$((total - 1))
                ;;
            B|j) # Down arrow or j
                ((current++))
                [[ $current -ge $total ]] && current=0
                ;;
            ' ') # Space - toggle
                if [[ ${selected[$current]} -eq 1 ]]; then
                    selected[$current]=0
                else
                    selected[$current]=1
                fi
                ;;
            a) # Select all
                for ((i=0; i<total; i++)); do
                    selected[$i]=1
                done
                ;;
            n) # Select none
                for ((i=0; i<total; i++)); do
                    selected[$i]=0
                done
                ;;
            s) # Skip entirely
                SELECTED_PACKAGES=""
                SKIP_PROFILE=true
                return 0
                ;;
            '') # Enter - confirm
                done=true
                ;;
        esac
    done
    
    # Build result
    SELECTED_PACKAGES=""
    SKIP_PROFILE=false
    for ((i=0; i<total; i++)); do
        if [[ ${selected[$i]} -eq 1 ]]; then
            local pkg_info="${packages[$i]}"
            local pkg_name="${pkg_info%%:*}"
            SELECTED_PACKAGES="$SELECTED_PACKAGES $pkg_name"
        fi
    done
    
    SELECTED_PACKAGES="${SELECTED_PACKAGES# }"  # Trim leading space
}

# Simple yes/no/customize menu for profile
profile_menu() {
    local profile_name="$1"
    local profile_icon="$2"
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${profile_icon} ${WHITE}${profile_name}${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${YELLOW}1${NC}. Install all packages (recommended)"
    echo -e "  ${YELLOW}2${NC}. Customize - choose specific packages"
    echo -e "  ${YELLOW}3${NC}. Skip this profile entirely"
    echo ""
    read -p "  Choose [1/2/3]: " choice
    
    echo "$choice"
}

#------------------------------------------------------------------------------
# Profile Definitions with Package Lists
#------------------------------------------------------------------------------

# Development packages
DEV_PACKAGES=(
    "git:Version control system"
    "python3:Python programming language"
    "python3-pip:Python package installer"
    "nodejs:JavaScript runtime"
    "npm:Node.js package manager"
    "build-essential:GCC, make, and basic build tools"
    "cmake:Cross-platform build system"
    "vim:Powerful text editor"
    "neovim:Modern vim-based editor"
    "tmux:Terminal multiplexer"
    "htop:Interactive process viewer"
    "curl:Command-line HTTP client"
    "wget:File downloader"
    "jq:JSON processor"
    "ripgrep:Fast search tool"
)

# Web hosting packages
WEB_PACKAGES=(
    "nginx:High-performance web server"
    "php-fpm:PHP FastCGI Process Manager"
    "php-cli:PHP command-line interface"
    "php-mysql:PHP MySQL extension"
    "php-curl:PHP cURL extension"
    "php-gd:PHP image processing"
    "php-mbstring:PHP multibyte string support"
    "php-xml:PHP XML support"
    "certbot:SSL certificate automation"
    "sqlite3:Lightweight database"
)

# File sharing packages
FILE_PACKAGES=(
    "openssh-sftp-server:SFTP server for file transfer"
    "rsync:Fast file synchronization"
    "rclone:Cloud storage sync tool"
    "zip:ZIP archive creation"
    "unzip:ZIP archive extraction"
    "p7zip-full:7-Zip archive support"
    "filebrowser:Web-based file manager"
)

# Database packages
DB_PACKAGES=(
    "mariadb-server:MySQL-compatible database server"
    "mariadb-client:MySQL command-line client"
    "postgresql:Advanced SQL database"
    "redis-server:In-memory data store"
    "sqlite3:Lightweight file-based database"
)

#------------------------------------------------------------------------------
# Export functions and variables for use by other scripts
#------------------------------------------------------------------------------

export -f select_packages
export -f profile_menu

# If run directly, show a demo
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Interactive Package Selector"
    echo "This script is meant to be sourced by other scripts."
    echo ""
    echo "Usage in your script:"
    echo "  source scripts/package-selector.sh"
    echo "  select_packages \"Development\" \"\${DEV_PACKAGES[@]}\""
    echo "  echo \"Selected: \$SELECTED_PACKAGES\""
fi
