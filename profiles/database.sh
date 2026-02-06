#!/data/data/com.termux/files/usr/bin/bash

#==============================================================================
#  Database Server Profile
#  Installs: MariaDB, PostgreSQL, Redis, SQLite
#==============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
DIM='\033[2m'

# Package definitions
DB_PACKAGES=(
    "mariadb:MySQL-compatible database server:mariadb-server mariadb-client"
    "postgresql:Advanced relational database:postgresql postgresql-contrib"
    "redis:In-memory data store and cache:redis-server"
    "sqlite:Lightweight file-based database:sqlite3 libsqlite3-dev"
    "db-tools:CLI tools (mycli, pgcli):SPECIAL_DB_TOOLS"
)

select_db_packages() {
    local selected=()
    local total=${#DB_PACKAGES[@]}
    
    for ((i=0; i<total; i++)); do selected[$i]=1; done
    
    local current=0
    local done=false
    
    if [[ ! -t 0 ]]; then
        INSTALL_PACKAGES="mariadb-server mariadb-client postgresql redis-server sqlite3"
        INSTALL_DB_TOOLS=true
        return 0
    fi
    
    while ! $done; do
        clear
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}  🗄️  ${WHITE}Database Server - Package Selection${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC}  ${DIM}↑/↓: Navigate  SPACE: Toggle  A: All  N: None  ENTER: Install${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        for ((i=0; i<total; i++)); do
            IFS=':' read -r pkg_name pkg_desc pkg_apt <<< "${DB_PACKAGES[$i]}"
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
    INSTALL_DB_TOOLS=false
    SKIP_PROFILE=false
    INSTALL_MARIADB=false
    INSTALL_POSTGRES=false
    INSTALL_REDIS=false
    
    for ((i=0; i<total; i++)); do
        if [[ ${selected[$i]} -eq 1 ]]; then
            local pkg_name="${DB_PACKAGES[$i]%%:*}"
            local pkg_apt="${DB_PACKAGES[$i]##*:}"
            
            case "$pkg_name" in
                mariadb) INSTALL_MARIADB=true; INSTALL_PACKAGES="$INSTALL_PACKAGES $pkg_apt" ;;
                postgresql) INSTALL_POSTGRES=true; INSTALL_PACKAGES="$INSTALL_PACKAGES $pkg_apt" ;;
                redis) INSTALL_REDIS=true; INSTALL_PACKAGES="$INSTALL_PACKAGES $pkg_apt" ;;
                sqlite) INSTALL_PACKAGES="$INSTALL_PACKAGES $pkg_apt" ;;
                db-tools) INSTALL_DB_TOOLS=true ;;
            esac
        fi
    done
}

install_packages() {
    [[ -z "$INSTALL_PACKAGES" && "$INSTALL_DB_TOOLS" != "true" ]] && { 
        echo -e "${YELLOW}Skipping Database Server${NC}"; return 0; 
    }
    
    echo -e "${CYAN}Installing Database packages...${NC}"
    
    cat > "$HOME/.vps-on-phone/install-db.sh" << INSTALL_SCRIPT
#!/bin/bash
set -e

apt update
apt install -y $INSTALL_PACKAGES

# Configure MariaDB if installed
if [ "$INSTALL_MARIADB" = "true" ]; then
    echo "Configuring MariaDB..."
    mkdir -p /run/mysqld
    chown mysql:mysql /run/mysqld 2>/dev/null || true
    
    cat > /etc/mysql/mariadb.conf.d/99-proot.cnf << 'CONF'
[mysqld]
user = root
skip-grant-tables
bind-address = 127.0.0.1
CONF
    
    if [ ! -d "/var/lib/mysql/mysql" ]; then
        mysql_install_db --user=root --datadir=/var/lib/mysql
    fi
    echo "MariaDB configured"
fi

# Configure PostgreSQL if installed
if [ "$INSTALL_POSTGRES" = "true" ]; then
    echo "Configuring PostgreSQL..."
    mkdir -p /var/run/postgresql
    chown postgres:postgres /var/run/postgresql 2>/dev/null || true
    echo "PostgreSQL configured"
fi

# Configure Redis if installed
if [ "$INSTALL_REDIS" = "true" ]; then
    echo "Redis configured on port 6379"
fi

# Install DB CLI tools via pip
if [ "$INSTALL_DB_TOOLS" = "true" ]; then
    echo "Installing database CLI tools..."
    pip3 install --break-system-packages mycli pgcli 2>/dev/null || \
    pip3 install mycli pgcli 2>/dev/null || true
fi

echo ""
echo "✓ Database packages installed!"
echo ""
echo "Quick start commands:"
[ "$INSTALL_MARIADB" = "true" ] && echo "  MariaDB: mysql -u root"
[ "$INSTALL_POSTGRES" = "true" ] && echo "  PostgreSQL: sudo -u postgres psql"
[ "$INSTALL_REDIS" = "true" ] && echo "  Redis: redis-cli"
INSTALL_SCRIPT

    chmod +x "$HOME/.vps-on-phone/install-db.sh"
    
    # Export variables for the script
    export INSTALL_MARIADB INSTALL_POSTGRES INSTALL_REDIS INSTALL_DB_TOOLS
    proot-distro login ubuntu -- bash /data/data/com.termux/files/home/.vps-on-phone/install-db.sh
    
    echo -e "${GREEN}✓ Database Server profile complete!${NC}"
}

main() {
    echo -e "📦 ${WHITE}Database Server Profile${NC}"
    select_db_packages
    [[ "$SKIP_PROFILE" == "true" ]] && { echo -e "${YELLOW}Skipping Database Server${NC}"; return 0; }
    install_packages
}

main "$@"
