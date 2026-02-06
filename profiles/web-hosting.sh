#!/data/data/com.termux/files/usr/bin/bash

#==============================================================================
#  Web Hosting Profile
#  Installs: Nginx, PHP, SSL support, static site hosting
#==============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
DIM='\033[2m'

# Package definitions: "name:description:apt_packages"
WEB_PACKAGES=(
    "nginx:High-performance web server:nginx"
    "php-core:PHP core and CLI:php-fpm php-cli php-common"
    "php-database:PHP database extensions:php-mysql php-pgsql php-sqlite3"
    "php-extensions:Common PHP extensions:php-curl php-gd php-mbstring php-xml php-json php-zip php-bcmath"
    "certbot:Let's Encrypt SSL automation:certbot python3-certbot-nginx"
    "sqlite:Lightweight database:sqlite3"
)

select_web_packages() {
    local selected=()
    local total=${#WEB_PACKAGES[@]}
    
    for ((i=0; i<total; i++)); do selected[$i]=1; done
    
    local current=0
    local done=false
    
    if [[ ! -t 0 ]]; then
        INSTALL_PACKAGES=""
        for pkg_info in "${WEB_PACKAGES[@]}"; do
            INSTALL_PACKAGES="$INSTALL_PACKAGES ${pkg_info##*:}"
        done
        return 0
    fi
    
    while ! $done; do
        clear
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}  🌐 ${WHITE}Web Hosting - Package Selection${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC}  ${DIM}↑/↓: Navigate  SPACE: Toggle  A: All  N: None  ENTER: Install${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        for ((i=0; i<total; i++)); do
            IFS=':' read -r pkg_name pkg_desc pkg_apt <<< "${WEB_PACKAGES[$i]}"
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
    SKIP_PROFILE=false
    for ((i=0; i<total; i++)); do
        [[ ${selected[$i]} -eq 1 ]] && INSTALL_PACKAGES="$INSTALL_PACKAGES ${WEB_PACKAGES[$i]##*:}"
    done
}

install_packages() {
    [[ -z "$INSTALL_PACKAGES" ]] && { echo -e "${YELLOW}Skipping Web Hosting${NC}"; return 0; }
    
    echo -e "${CYAN}Installing Web Hosting packages...${NC}"
    
    cat > "$HOME/.vps-on-phone/install-web.sh" << INSTALL_SCRIPT
#!/bin/bash
set -e

apt update
apt install -y $INSTALL_PACKAGES

# Create web root
mkdir -p /var/www/html

# Create welcome page
cat > /var/www/html/index.html << 'WELCOME'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>VPS-on-Phone</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: system-ui, sans-serif;
            background: linear-gradient(135deg, #1a1a2e, #16213e);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #fff;
        }
        .container { text-align: center; }
        .logo { font-size: 4rem; margin-bottom: 1rem; }
        h1 { background: linear-gradient(90deg, #00d9ff, #00ff88); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
        .status { padding: 0.5rem 1.5rem; background: rgba(0,255,136,0.2); border: 1px solid #00ff88; border-radius: 50px; color: #00ff88; margin-top: 1rem; display: inline-block; }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">📱</div>
        <h1>VPS-on-Phone</h1>
        <p>Your phone is now a web server!</p>
        <div class="status">🟢 Running</div>
    </div>
</body>
</html>
WELCOME

echo "✓ Web Hosting packages installed!"
INSTALL_SCRIPT

    chmod +x "$HOME/.vps-on-phone/install-web.sh"
    proot-distro login ubuntu -- bash /data/data/com.termux/files/home/.vps-on-phone/install-web.sh
    
    echo -e "${GREEN}✓ Web Hosting profile complete!${NC}"
}

main() {
    echo -e "📦 ${WHITE}Web Hosting Profile${NC}"
    select_web_packages
    [[ "$SKIP_PROFILE" == "true" ]] && { echo -e "${YELLOW}Skipping Web Hosting${NC}"; return 0; }
    install_packages
}

main "$@"
