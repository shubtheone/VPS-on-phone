#!/bin/bash

#==============================================================================
#  Quick Test Script for Ubuntu
#  Tests VPS-on-Phone dashboard on Ubuntu before deploying to Termux
#==============================================================================

set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_DIR="$SCRIPT_DIR/dashboard"

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║      📱 VPS-on-Phone - Ubuntu Testing Setup              ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}⚠ Python 3 not found. Installing...${NC}"
    sudo apt update
    sudo apt install -y python3 python3-pip python3-venv
fi

# Create virtual environment if it doesn't exist
if [ ! -d "$DASHBOARD_DIR/venv" ]; then
    echo -e "${CYAN}Creating Python virtual environment...${NC}"
    cd "$DASHBOARD_DIR"
    python3 -m venv venv
fi

# Activate virtual environment
echo -e "${CYAN}Activating virtual environment...${NC}"
source "$DASHBOARD_DIR/venv/bin/activate"

# Install requirements
echo -e "${CYAN}Installing Python dependencies...${NC}"
cd "$DASHBOARD_DIR"
pip install -q -r requirements.txt

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✓ Setup Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}Starting dashboard on http://localhost:5000${NC}"
echo ""
echo -e "  ${YELLOW}Test these features:${NC}"
echo -e "    ✅ Todo List - Add and manage tasks"
echo -e "    ⬇️  Downloads - Download files to your VPS"
echo -e "    📊 Dashboard - View system stats"
echo ""
echo -e "  ${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

# Start the dashboard
python3 app.py
