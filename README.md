# VPS-on-Phone

Transform your Android phone into a full-featured VPS using Termux.

## Features

- 🐧 **Full Ubuntu Environment** - Ubuntu running via proot-distro
- 📊 **Web Dashboard** - Monitor services, resources, and connections
- 🔐 **SSH Access** - Secure remote terminal access
- 🌐 **Web Hosting** - Nginx with PHP support
- 📁 **File Sharing** - SFTP and web file manager
- 🗄️ **Databases** - MariaDB, PostgreSQL, Redis
- 🚀 **Easy Setup** - One script to install everything
- 🔋 **Battery Optimization** - Wake lock support for persistent operation

## Quick Start

### Prerequisites

1. Install **Termux** from [F-Droid](https://f-droid.org/packages/com.termux/)
2. (Optional) Install **Termux:Boot** from F-Droid for auto-start
3. (Optional) Install **Termux:API** from F-Droid for battery info

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/vps-on-phone.git
cd vps-on-phone

# Make setup script executable
chmod +x vps-setup.sh

# Run setup
./vps-setup.sh
```

### Usage

```bash
# Start all VPS services
./vps-start.sh

# Stop all VPS services
./vps-stop.sh

# Manage individual services
./scripts/services.sh start nginx
./scripts/services.sh stop ssh
./scripts/services.sh status

# Manage tunnel
./scripts/tunnel.sh
```

## Profiles

During setup, choose which components to install:

| Profile | Description |
|---------|-------------|
| 🖥️ Development | Git, Python, Node.js, build tools |
| 🌐 Web Hosting | Nginx, PHP, SSL support |
| 📁 File Sharing | SFTP, FileBrowser (web UI) |
| 🗄️ Database | MariaDB, PostgreSQL, Redis |
| 📚 Learning Lab | Everything above |

## Network Access

Choose your tunnel for external access:

### Cloudflare Tunnel
- Public URLs accessible by anyone
- Built-in DDoS protection
- Automatic SSL

### Tailscale
- Private VPN access
- Only your devices can connect
- Zero-config setup

## Dashboard

Access the web dashboard at `http://localhost:5000`

Features:
- Real-time service monitoring
- System resource usage (CPU, RAM, Disk)
- Service control (start/stop/restart)
- Connection info with copy buttons
- Battery status

## Directory Structure

```
vps-on-phone/
├── vps-setup.sh          # Main installation script
├── vps-start.sh          # Start all services
├── vps-stop.sh           # Stop all services
├── dashboard/            # Web dashboard
│   ├── app.py           # Flask backend
│   ├── templates/       # HTML templates
│   └── static/          # CSS and JS
├── scripts/              # Helper scripts
│   ├── services.sh      # Service management
│   └── tunnel.sh        # Tunnel management
└── profiles/             # Installation profiles
    ├── development.sh
    ├── web-hosting.sh
    ├── file-sharing.sh
    └── database.sh
```

## Default Credentials

⚠️ **Change these immediately after setup!**

| Service | User | Password |
|---------|------|----------|
| SSH/Ubuntu | vps | vpspassword |
| FileBrowser | admin | admin |
| MariaDB | vps | vpspassword |

## Tips

### Keep VPS Running
- The script automatically acquires a wake lock
- Install Termux:Boot for auto-start on device boot
- Keep the phone plugged in for best performance

### Performance
- Close other apps to free up RAM
- Use a fast microSD card for storage
- Enable high-performance mode if available

### Security
1. Change all default passwords
2. Use SSH key authentication
3. Keep packages updated
4. Only expose necessary ports

## Troubleshooting

### Services not starting
```bash
# Check service status
./scripts/services.sh status

# Check logs
proot-distro login ubuntu -- cat /var/log/dashboard.log
```

### No network access
```bash
# Reconfigure tunnel
./scripts/tunnel.sh
```

### Out of storage
```bash
# Check disk usage
proot-distro login ubuntu -- df -h
```

## License

MIT License - Feel free to modify and share!

## Contributing

Contributions welcome! Please open an issue or PR.
# VPS-on-phone
