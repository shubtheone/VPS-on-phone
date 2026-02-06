#!/data/data/com.termux/files/usr/bin/bash

#==============================================================================
#  Tunnel Management Script
#  Configure and manage Cloudflare Tunnel or Tailscale
#==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

DATA_DIR="$HOME/.vps-on-phone"

show_menu() {
    echo -e "\n${CYAN}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       🌐 Tunnel Management                 ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════╝${NC}\n"
    
    echo "1. Setup Cloudflare Tunnel"
    echo "2. Setup Tailscale"
    echo "3. Start tunnel"
    echo "4. Stop tunnel"
    echo "5. Show tunnel status"
    echo "6. Quick tunnel (temporary URL)"
    echo "0. Exit"
    echo ""
    read -p "Select option: " choice
}

setup_cloudflare() {
    echo -e "${CYAN}Setting up Cloudflare Tunnel...${NC}"
    
    proot-distro login ubuntu -- bash << 'CF'
#!/bin/bash
if ! command -v cloudflared &> /dev/null; then
    ARCH=$(dpkg --print-architecture)
    [[ "$ARCH" == "arm64" ]] && CF_ARCH="arm64" || CF_ARCH="arm"
    wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$CF_ARCH" -O /usr/local/bin/cloudflared
    chmod +x /usr/local/bin/cloudflared
fi

echo ""
echo "Run 'cloudflared tunnel login' to authenticate"
echo "Then 'cloudflared tunnel create vps-phone' to create tunnel"
CF
    
    echo "cloudflare" > "$DATA_DIR/tunnel_type"
    echo -e "${GREEN}Cloudflare Tunnel installed!${NC}"
}

setup_tailscale() {
    echo -e "${CYAN}Setting up Tailscale...${NC}"
    
    proot-distro login ubuntu -- bash << 'TS'
#!/bin/bash
if ! command -v tailscale &> /dev/null; then
    curl -fsSL https://tailscale.com/install.sh | sh
fi
echo "Run 'tailscaled &' then 'tailscale up' to connect"
TS
    
    echo "tailscale" > "$DATA_DIR/tunnel_type"
    echo -e "${GREEN}Tailscale installed!${NC}"
}

start_tunnel() {
    local type=$(cat "$DATA_DIR/tunnel_type" 2>/dev/null || echo "none")
    
    case $type in
        cloudflare)
            echo -e "${CYAN}Starting Cloudflare quick tunnel...${NC}"
            proot-distro login ubuntu -- cloudflared tunnel --url localhost:80 &
            ;;
        tailscale)
            echo -e "${CYAN}Starting Tailscale...${NC}"
            proot-distro login ubuntu -- bash -c "tailscaled & sleep 2 && tailscale up"
            ;;
        *)
            echo -e "${YELLOW}No tunnel configured. Run setup first.${NC}"
            ;;
    esac
}

stop_tunnel() {
    echo -e "${CYAN}Stopping tunnels...${NC}"
    proot-distro login ubuntu -- pkill cloudflared 2>/dev/null
    proot-distro login ubuntu -- pkill tailscaled 2>/dev/null
    echo -e "${GREEN}Tunnels stopped${NC}"
}

show_status() {
    local type=$(cat "$DATA_DIR/tunnel_type" 2>/dev/null || echo "none")
    echo -e "\n${CYAN}Tunnel Type:${NC} $type"
    
    echo -e "\n${CYAN}Running processes:${NC}"
    proot-distro login ubuntu -- bash -c "pgrep -a cloudflared || echo 'Cloudflare: not running'"
    proot-distro login ubuntu -- bash -c "pgrep -a tailscaled || echo 'Tailscale: not running'"
}

quick_tunnel() {
    echo -e "${CYAN}Starting temporary Cloudflare tunnel...${NC}"
    echo -e "${YELLOW}This creates a temporary public URL (no login needed)${NC}"
    proot-distro login ubuntu -- cloudflared tunnel --url localhost:80
}

# Main loop
while true; do
    show_menu
    case $choice in
        1) setup_cloudflare ;;
        2) setup_tailscale ;;
        3) start_tunnel ;;
        4) stop_tunnel ;;
        5) show_status ;;
        6) quick_tunnel ;;
        0) exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac
done
