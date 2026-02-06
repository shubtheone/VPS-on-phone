#!/data/data/com.termux/files/usr/bin/bash

#==============================================================================
#  VPS-on-Phone Stop Script
#  Stops all VPS services
#==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}Stopping VPS services...${NC}"

# Stop services in Ubuntu
proot-distro login ubuntu -- bash << 'STOP'
#!/bin/bash
pkill -f "python3 app.py" 2>/dev/null && echo "✓ Dashboard stopped"
pkill sshd 2>/dev/null && echo "✓ SSH stopped"
pkill nginx 2>/dev/null && echo "✓ Nginx stopped"
pkill mysqld 2>/dev/null && echo "✓ MariaDB stopped"
pkill redis-server 2>/dev/null && echo "✓ Redis stopped"
pkill filebrowser 2>/dev/null && echo "✓ FileBrowser stopped"
pkill cloudflared 2>/dev/null && echo "✓ Cloudflare tunnel stopped"
echo "All services stopped"
STOP

# Release wake lock
echo -e "${CYAN}Releasing wake lock...${NC}"
termux-wake-unlock 2>/dev/null || echo "Note: termux-wake-unlock not available"

echo ""
echo -e "${GREEN}VPS services stopped and wake lock released.${NC}"
echo -e "Run ${CYAN}bash vps-start.sh${NC} to start again."
echo ""
