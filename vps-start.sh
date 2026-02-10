#!/data/data/com.termux/files/usr/bin/bash

#==============================================================================
#  VPS-on-Phone Start Script
#  Starts all VPS services
#==============================================================================

CYAN='\033[0;36m'
GREEN='\033[0;32m'
WHITE='\033[1;37m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║          📱 VPS-on-Phone - Starting Services              ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${CYAN}Acquiring wake lock...${NC}"
termux-wake-lock 2>/dev/null || echo "Note: termux-wake-lock not available"
echo -e "${GREEN}✓ Wake lock acquired${NC}"

echo -e "${CYAN}Starting services in Ubuntu...${NC}"

proot-distro login ubuntu -- bash << 'SERVICES'
#!/bin/bash

echo "Starting SSH server..."
/usr/sbin/sshd 2>/dev/null && echo "✓ SSH started" || echo "SSH already running"

if command -v nginx &> /dev/null; then
    echo "Starting Nginx..."
    nginx 2>/dev/null && echo "✓ Nginx started" || echo "Nginx already running"
fi

# Check for filebrowser
if command -v filebrowser &> /dev/null; then
    echo "Starting File Manager..."
    # Ensure the database directory exists
    mkdir -p /var/lib/filebrowser
    # Start filebrowser in the background
    nohup filebrowser -d /var/lib/filebrowser/filebrowser.db --baseURL /filebrowser > /var/log/filebrowser.log 2>&1 &
    echo "✓ File Manager started"
fi

echo "Starting dashboard..."
if [ -d /opt/vps-dashboard ]; then
    cd /opt/vps-dashboard
    source venv/bin/activate 2>/dev/null
    nohup python3 app.py > /var/log/dashboard.log 2>&1 &
    echo "✓ Dashboard started"
fi
SERVICES

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  VPS Services Started Successfully!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${WHITE}Dashboard:${NC}  ${CYAN}http://localhost:5000${NC}"
echo -e "  ${WHITE}SSH:${NC}        ${CYAN}ssh vps@localhost -p 22${NC}"
echo ""
echo -e "  ${YELLOW}To configure external access:${NC}"
echo -e "    ${CYAN}bash scripts/tunnel.sh${NC}"
echo ""
echo -e "  ${WHITE}To stop all services:${NC} ${CYAN}bash vps-stop.sh${NC}"
echo ""
