#!/data/data/com.termux/files/usr/bin/bash

#==============================================================================
#  VPS-on-Phone Setup Script
#  Transforms your Android phone into a full-featured VPS using Termux
#==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
PROFILES_DIR="$SCRIPT_DIR/profiles"
DASHBOARD_DIR="$SCRIPT_DIR/dashboard"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
DATA_DIR="$HOME/.vps-on-phone"

# State file to track installation
STATE_FILE="$DATA_DIR/state.json"

#------------------------------------------------------------------------------
# Utility Functions
#------------------------------------------------------------------------------

print_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
 ╔═══════════════════════════════════════════════════════════════╗
 ║                                                               ║
 ║   ██╗   ██╗██████╗ ███████╗     ██████╗ ███╗   ██╗            ║
 ║   ██║   ██║██╔══██╗██╔════╝    ██╔═══██╗████╗  ██║            ║
 ║   ██║   ██║██████╔╝███████╗    ██║   ██║██╔██╗ ██║            ║
 ║   ╚██╗ ██╔╝██╔═══╝ ╚════██║    ██║   ██║██║╚██╗██║            ║
 ║    ╚████╔╝ ██║     ███████║    ╚██████╔╝██║ ╚████║            ║
 ║     ╚═══╝  ╚═╝     ╚══════╝     ╚═════╝ ╚═╝  ╚═══╝            ║
 ║                                                               ║
 ║              📱 PHONE  ──────────────────────                 ║
 ║                                                               ║
 ║      Transform your phone into a powerful VPS                 ║
 ║                                                               ║
 ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

confirm() {
    local prompt="$1"
    local default="${2:-y}"
    
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    
    read -p "$prompt" response
    response=${response:-$default}
    
    [[ "$response" =~ ^[Yy]$ ]]
}

#------------------------------------------------------------------------------
# Prerequisites Check
#------------------------------------------------------------------------------

check_prerequisites() {
    print_step "📋 Checking Prerequisites"
    
    # Check if running in Termux
    if [[ ! -d "/data/data/com.termux" ]]; then
        print_error "This script must be run in Termux!"
        print_info "Install Termux from F-Droid: https://f-droid.org/packages/com.termux/"
        exit 1
    fi
    print_success "Running in Termux"
    
    # Check internet connectivity
    if ! ping -c 1 google.com &> /dev/null; then
        print_error "No internet connection detected!"
        exit 1
    fi
    print_success "Internet connection available"
    
    # Check storage permission
    if [[ ! -d "$HOME/storage" ]]; then
        print_warning "Storage permission not granted"
        print_info "Requesting storage permission..."
        termux-setup-storage
        sleep 2
    fi
    print_success "Storage permission configured"
    
    # Create data directory
    mkdir -p "$DATA_DIR"
    print_success "Data directory created at $DATA_DIR"
    
    echo ""
    print_success "All prerequisites met!"
}

#------------------------------------------------------------------------------
# Base System Setup
#------------------------------------------------------------------------------

setup_base_system() {
    print_step "🔧 Setting Up Base System"
    
    print_info "Updating Termux packages..."
    pkg update -y
    pkg upgrade -y
    
    print_info "Installing essential packages..."
    pkg install -y \
        proot-distro \
        termux-services \
        termux-api \
        openssh \
        wget \
        curl \
        git \
        jq \
        tmux \
        htop \
        nano \
        vim
    
    print_success "Base packages installed"
    
    # Setup termux-services
    print_info "Setting up termux-services..."
    if [[ ! -d "$PREFIX/var/service" ]]; then
        mkdir -p "$PREFIX/var/service"
    fi
    
    print_success "Base system setup complete"
}

#------------------------------------------------------------------------------
# Ubuntu Setup via proot-distro
#------------------------------------------------------------------------------

setup_ubuntu() {
    print_step "🐧 Setting Up Ubuntu Environment"
    
    # Check if Ubuntu is already installed
    if proot-distro list | grep -q "ubuntu.*installed"; then
        print_warning "Ubuntu is already installed"
        if confirm "Reinstall Ubuntu? (This will delete existing installation)"; then
            proot-distro remove ubuntu
        else
            print_info "Keeping existing Ubuntu installation"
            return 0
        fi
    fi
    
    print_info "Installing Ubuntu... (This may take a few minutes)"
    proot-distro install ubuntu
    
    print_info "Configuring Ubuntu environment..."
    
    # Create setup script for inside Ubuntu
    cat > "$DATA_DIR/ubuntu-setup.sh" << 'UBUNTU_SETUP'
#!/bin/bash
set -e

echo "Updating Ubuntu packages..."
apt update && apt upgrade -y

echo "Installing essential packages..."
apt install -y \
    sudo \
    curl \
    wget \
    git \
    htop \
    nano \
    vim \
    tmux \
    python3 \
    python3-pip \
    python3-venv \
    openssh-server \
    net-tools \
    iproute2 \
    procps

# Create vps user
if ! id "vps" &>/dev/null; then
    useradd -m -s /bin/bash vps
    echo "vps:vpspassword" | chpasswd
    usermod -aG sudo vps
    echo "vps ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
fi

echo "Ubuntu setup complete!"
UBUNTU_SETUP
    
    chmod +x "$DATA_DIR/ubuntu-setup.sh"
    
    # Run setup inside Ubuntu
    proot-distro login ubuntu -- bash /data/data/com.termux/files/home/.vps-on-phone/ubuntu-setup.sh
    
    print_success "Ubuntu environment configured"
}

#------------------------------------------------------------------------------
# Use-Case Selection
#------------------------------------------------------------------------------

select_profiles() {
    print_step "🎯 Select Your Use Cases"
    
    echo -e "${WHITE}What will you use this VPS for?${NC}"
    echo -e "${CYAN}(Enter numbers separated by spaces, e.g., '1 2 3')${NC}\n"
    
    echo -e "  ${YELLOW}1${NC}. 🖥️  ${WHITE}Development Server${NC}"
    echo -e "     ${CYAN}→ Git, Python, Node.js, build tools, code editors${NC}\n"
    
    echo -e "  ${YELLOW}2${NC}. 🌐 ${WHITE}Web Hosting${NC}"
    echo -e "     ${CYAN}→ Nginx, PHP, SSL support, static site hosting${NC}\n"
    
    echo -e "  ${YELLOW}3${NC}. 📁 ${WHITE}File Sharing${NC}"
    echo -e "     ${CYAN}→ SFTP, Web file manager, rsync${NC}\n"
    
    echo -e "  ${YELLOW}4${NC}. 🗄️  ${WHITE}Database Server${NC}"
    echo -e "     ${CYAN}→ MariaDB/MySQL, PostgreSQL, Redis${NC}\n"
    
    echo -e "  ${YELLOW}5${NC}. 📚 ${WHITE}Learning Lab${NC}"
    echo -e "     ${CYAN}→ Everything above - full installation${NC}\n"
    
    read -p "Enter your choices: " choices
    
    # Default to development if nothing selected
    if [[ -z "$choices" ]]; then
        choices="1"
    fi
    
    # Save selected profiles
    echo "$choices" > "$DATA_DIR/selected_profiles"
    
    # Install selected profiles
    for choice in $choices; do
        case $choice in
            1) install_profile "development" ;;
            2) install_profile "web-hosting" ;;
            3) install_profile "file-sharing" ;;
            4) install_profile "database" ;;
            5) 
                install_profile "development"
                install_profile "web-hosting"
                install_profile "file-sharing"
                install_profile "database"
                ;;
            *)
                print_warning "Unknown option: $choice"
                ;;
        esac
    done
}

install_profile() {
    local profile="$1"
    local profile_script="$PROFILES_DIR/${profile}.sh"
    
    if [[ -f "$profile_script" ]]; then
        print_info "Installing profile: $profile"
        bash "$profile_script"
        print_success "Profile '$profile' installed"
    else
        print_warning "Profile script not found: $profile_script"
    fi
}

#------------------------------------------------------------------------------
# Network Tunnel Selection
#------------------------------------------------------------------------------

select_tunnel() {
    print_step "🌐 Configure Network Access"
    
    echo -e "${WHITE}How should this VPS be accessible?${NC}\n"
    
    echo -e "  ${YELLOW}1${NC}. 🌍 ${WHITE}Public Access (Cloudflare Tunnel)${NC}"
    echo -e "     ${GREEN}Pros:${NC}"
    echo -e "       ${CYAN}✓ Public URLs - anyone can connect with the link${NC}"
    echo -e "       ${CYAN}✓ Built-in DDoS protection${NC}"
    echo -e "       ${CYAN}✓ Free tier is generous${NC}"
    echo -e "       ${CYAN}✓ Automatic SSL/HTTPS${NC}"
    echo -e "     ${RED}Cons:${NC}"
    echo -e "       ${CYAN}✗ Requires Cloudflare account (free)${NC}"
    echo -e "       ${CYAN}✗ Need to own a domain (or use trycloudflare.com for testing)${NC}"
    echo ""
    
    echo -e "  ${YELLOW}2${NC}. 🔒 ${WHITE}Private Access (Tailscale)${NC}"
    echo -e "     ${GREEN}Pros:${NC}"
    echo -e "       ${CYAN}✓ Zero-config VPN setup${NC}"
    echo -e "       ${CYAN}✓ Only your linked devices can connect (secure)${NC}"
    echo -e "       ${CYAN}✓ Great for personal development${NC}"
    echo -e "       ${CYAN}✓ Very fast (WireGuard-based)${NC}"
    echo -e "       ${CYAN}✓ Works behind any NAT/firewall${NC}"
    echo -e "     ${RED}Cons:${NC}"
    echo -e "       ${CYAN}✗ Requires Tailscale account (free)${NC}"
    echo -e "       ${CYAN}✗ Not publicly accessible (by design)${NC}"
    echo ""
    
    echo -e "  ${YELLOW}3${NC}. ⏭️  ${WHITE}Skip for now${NC}"
    echo -e "     ${CYAN}→ Configure tunneling later${NC}"
    echo ""
    
    read -p "Enter your choice [1/2/3]: " tunnel_choice
    
    case $tunnel_choice in
        1)
            setup_cloudflare_tunnel
            echo "cloudflare" > "$DATA_DIR/tunnel_type"
            ;;
        2)
            setup_tailscale
            echo "tailscale" > "$DATA_DIR/tunnel_type"
            ;;
        3)
            print_info "Skipping tunnel setup. Run 'bash scripts/tunnel.sh' later to configure."
            echo "none" > "$DATA_DIR/tunnel_type"
            ;;
        *)
            print_warning "Invalid choice, skipping tunnel setup"
            echo "none" > "$DATA_DIR/tunnel_type"
            ;;
    esac
}

setup_cloudflare_tunnel() {
    print_info "Setting up Cloudflare Tunnel..."
    
    # Install cloudflared in Ubuntu
    proot-distro login ubuntu -- bash << 'CF_SETUP'
#!/bin/bash
set -e

# Download and install cloudflared
ARCH=$(dpkg --print-architecture)
if [[ "$ARCH" == "aarch64" ]] || [[ "$ARCH" == "arm64" ]]; then
    CF_ARCH="arm64"
else
    CF_ARCH="arm"
fi

wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$CF_ARCH" -O /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared

echo "Cloudflared installed successfully!"
CF_SETUP

    print_success "Cloudflare Tunnel (cloudflared) installed"
    
    echo ""
    print_info "To complete Cloudflare Tunnel setup:"
    echo -e "  1. Run: ${YELLOW}proot-distro login ubuntu${NC}"
    echo -e "  2. Authenticate: ${YELLOW}cloudflared tunnel login${NC}"
    echo -e "  3. Create tunnel: ${YELLOW}cloudflared tunnel create vps-phone${NC}"
    echo -e "  4. Configure in dashboard or use quick tunnel: ${YELLOW}cloudflared tunnel --url localhost:80${NC}"
    echo ""
}

setup_tailscale() {
    print_info "Setting up Tailscale..."
    
    # Install Tailscale in Ubuntu
    proot-distro login ubuntu -- bash << 'TS_SETUP'
#!/bin/bash
set -e

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

echo "Tailscale installed successfully!"
echo "Note: Tailscale requires a TUN device which may not work in all proot environments."
echo "If it doesn't work, you can install Tailscale directly in Termux instead."
TS_SETUP

    print_success "Tailscale installed"
    
    echo ""
    print_info "To complete Tailscale setup:"
    echo -e "  1. Run: ${YELLOW}proot-distro login ubuntu${NC}"
    echo -e "  2. Start Tailscale: ${YELLOW}sudo tailscaled &${NC}"
    echo -e "  3. Authenticate: ${YELLOW}sudo tailscale up${NC}"
    echo ""
}

#------------------------------------------------------------------------------
# Dashboard Setup
#------------------------------------------------------------------------------

setup_dashboard() {
    print_step "📊 Setting Up Web Dashboard"
    
    # Install dashboard dependencies in Ubuntu
    proot-distro login ubuntu -- bash << DASH_SETUP
#!/bin/bash
set -e

# Create dashboard directory
mkdir -p /opt/vps-dashboard
cd /opt/vps-dashboard

# Create Python virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Flask and dependencies
pip install flask psutil requests yt-dlp

echo "Dashboard dependencies installed!"
DASH_SETUP

    # Copy dashboard files to Ubuntu
    print_info "Deploying dashboard files..."
    
    # Create directory for dashboard in proot
    proot-distro login ubuntu -- mkdir -p /opt/vps-dashboard/templates
    proot-distro login ubuntu -- mkdir -p /opt/vps-dashboard/static/css
    proot-distro login ubuntu -- mkdir -p /opt/vps-dashboard/static/js
    
    # Copy files using proot-distro
    cp "$DASHBOARD_DIR/app.py" "$HOME/.vps-on-phone/dashboard_app.py"
    cp "$DASHBOARD_DIR/templates/index.html" "$HOME/.vps-on-phone/dashboard_index.html"
    cp "$DASHBOARD_DIR/static/css/style.css" "$HOME/.vps-on-phone/dashboard_style.css"
    cp "$DASHBOARD_DIR/static/js/dashboard.js" "$HOME/.vps-on-phone/dashboard_script.js"
    
    proot-distro login ubuntu -- cp /data/data/com.termux/files/home/.vps-on-phone/dashboard_app.py /opt/vps-dashboard/app.py
    proot-distro login ubuntu -- cp /data/data/com.termux/files/home/.vps-on-phone/dashboard_index.html /opt/vps-dashboard/templates/index.html
    proot-distro login ubuntu -- cp /data/data/com.termux/files/home/.vps-on-phone/dashboard_style.css /opt/vps-dashboard/static/css/style.css
    proot-distro login ubuntu -- cp /data/data/com.termux/files/home/.vps-on-phone/dashboard_script.js /opt/vps-dashboard/static/js/dashboard.js
    
    print_success "Dashboard deployed to /opt/vps-dashboard"
}

#------------------------------------------------------------------------------
# SSH Configuration
#------------------------------------------------------------------------------

setup_ssh() {
    print_step "🔐 Configuring SSH Server"
    
    # Configure SSH in Ubuntu
    proot-distro login ubuntu -- bash << 'SSH_SETUP'
#!/bin/bash
set -e

# Configure SSH
mkdir -p /etc/ssh
mkdir -p /run/sshd

# Generate host keys if they don't exist
if [[ ! -f /etc/ssh/ssh_host_rsa_key ]]; then
    ssh-keygen -A
fi

# Create sshd_config
cat > /etc/ssh/sshd_config << 'SSHD_CONF'
Port 22
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM no
X11Forwarding no
PrintMotd yes
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
SSHD_CONF

echo "SSH server configured!"
echo "Default user: vps"
echo "Default password: vpspassword"
echo "IMPORTANT: Please change the password after first login!"
SSH_SETUP

    print_success "SSH server configured"
    print_warning "Default credentials - User: vps, Password: vpspassword"
    print_warning "Please change the password after first login!"
}

#------------------------------------------------------------------------------
# Create Startup Script
#------------------------------------------------------------------------------

create_startup_scripts() {
    print_step "🚀 Creating Startup Scripts"
    
    # Create the main vps-start.sh script
    cat > "$SCRIPT_DIR/vps-start.sh" << 'START_SCRIPT'
#!/data/data/com.termux/files/usr/bin/bash

#==============================================================================
#  VPS-on-Phone Start Script
#  Starts all VPS services
#==============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$HOME/.vps-on-phone"

print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║          📱 VPS-on-Phone - Starting Services              ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

start_services() {
    echo -e "${BLUE}Starting VPS services...${NC}\n"
    
    # Acquire wake lock to prevent phone from sleeping
    echo -e "${CYAN}Acquiring wake lock...${NC}"
    termux-wake-lock
    echo -e "${GREEN}✓ Wake lock acquired${NC}"
    
    # Start Ubuntu environment with services
    echo -e "${CYAN}Starting Ubuntu environment and services...${NC}"
    
    proot-distro login ubuntu -- bash << 'SERVICES'
#!/bin/bash

echo "Starting SSH server..."
/usr/sbin/sshd 2>/dev/null || echo "SSH already running or failed to start"

echo "Starting dashboard..."
cd /opt/vps-dashboard
source venv/bin/activate
nohup python3 app.py > /var/log/dashboard.log 2>&1 &

# Check for nginx
if command -v nginx &> /dev/null; then
    echo "Starting Nginx..."
    nginx 2>/dev/null || echo "Nginx already running or failed to start"
fi

# Check for MySQL/MariaDB
if command -v mysqld &> /dev/null; then
    echo "Starting MariaDB..."
    mysqld_safe &
fi

echo ""
echo "Services started!"
echo "Dashboard: http://localhost:5000"
echo "SSH: Port 22"
SERVICES

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  VPS Services Started Successfully!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${WHITE}Dashboard:${NC}  ${CYAN}http://localhost:5000${NC}"
    echo -e "  ${WHITE}SSH:${NC}        ${CYAN}ssh vps@localhost -p 22${NC}"
    echo ""
    echo -e "  ${YELLOW}To access from outside, configure your tunnel:${NC}"
    echo -e "    Cloudflare: ${CYAN}cloudflared tunnel --url localhost:80${NC}"
    echo -e "    Tailscale:  ${CYAN}tailscale up${NC}"
    echo ""
    echo -e "  ${WHITE}To stop all services:${NC} ${CYAN}bash vps-stop.sh${NC}"
    echo ""
}

print_banner
start_services
START_SCRIPT

    chmod +x "$SCRIPT_DIR/vps-start.sh"
    print_success "Created vps-start.sh"
    
    # Create stop script
    cat > "$SCRIPT_DIR/vps-stop.sh" << 'STOP_SCRIPT'
#!/data/data/com.termux/files/usr/bin/bash

echo "Stopping VPS services..."

# Stop services in Ubuntu
proot-distro login ubuntu -- bash << 'STOP'
pkill -f "python3 app.py" 2>/dev/null
pkill sshd 2>/dev/null
pkill nginx 2>/dev/null
pkill mysqld 2>/dev/null
echo "Services stopped"
STOP

# Release wake lock
termux-wake-unlock

echo "VPS services stopped and wake lock released."
STOP_SCRIPT

    chmod +x "$SCRIPT_DIR/vps-stop.sh"
    print_success "Created vps-stop.sh"
    
    # Create Termux:Boot script for auto-start
    BOOT_DIR="$HOME/.termux/boot"
    mkdir -p "$BOOT_DIR"
    
    cat > "$BOOT_DIR/start-vps.sh" << BOOT_SCRIPT
#!/data/data/com.termux/files/usr/bin/bash
# Auto-start VPS services on boot
cd "$SCRIPT_DIR"
bash vps-start.sh
BOOT_SCRIPT

    chmod +x "$BOOT_DIR/start-vps.sh"
    print_success "Created auto-start script for Termux:Boot"
    
    print_info "Install Termux:Boot from F-Droid for auto-start on device boot"
}

#------------------------------------------------------------------------------
# Final Summary
#------------------------------------------------------------------------------

print_summary() {
    print_step "✅ Installation Complete!"
    
    echo -e "${GREEN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║   🎉 VPS-on-Phone Setup Complete!                                 ║
║                                                                   ║
╠═══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║   QUICK START                                                     ║
║   ───────────                                                     ║
║   Start VPS:         bash vps-start.sh                            ║
║   Stop VPS:          bash vps-stop.sh                             ║
║   Enter Ubuntu:      proot-distro login ubuntu                    ║
║                                                                   ║
╠═══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║   ACCESS POINTS                                                   ║
║   ─────────────                                                   ║
║   Dashboard:         http://localhost:5000                        ║
║   SSH:               ssh vps@localhost (password: vpspassword)    ║
║   SFTP:              sftp://vps@localhost                         ║
║                                                                   ║
╠═══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║   ⚠️  IMPORTANT                                                   ║
║   ─────────────                                                   ║
║   1. Change the default password immediately!                     ║
║      Run: proot-distro login ubuntu                               ║
║      Then: passwd vps                                             ║
║                                                                   ║
║   2. Configure your tunnel for external access                    ║
║      Check: ~/.vps-on-phone/tunnel_type                           ║
║                                                                   ║
║   3. Install Termux:Boot for auto-start on device boot            ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo -e "\n${CYAN}Would you like to start the VPS now?${NC}"
    if confirm "Start VPS services?"; then
        bash "$SCRIPT_DIR/vps-start.sh"
    else
        echo -e "\n${WHITE}Run ${CYAN}bash vps-start.sh${WHITE} when you're ready to start.${NC}\n"
    fi
}

#------------------------------------------------------------------------------
# Main Execution
#------------------------------------------------------------------------------

main() {
    print_banner
    
    echo -e "${WHITE}Welcome to VPS-on-Phone setup!${NC}"
    echo -e "${CYAN}This script will transform your phone into a full-featured VPS.${NC}\n"
    
    if ! confirm "Ready to begin installation?"; then
        echo -e "\n${YELLOW}Installation cancelled.${NC}"
        exit 0
    fi
    
    check_prerequisites
    setup_base_system
    setup_ubuntu
    select_profiles
    select_tunnel
    setup_ssh
    setup_dashboard
    create_startup_scripts
    print_summary
}

# Run main function
main "$@"
