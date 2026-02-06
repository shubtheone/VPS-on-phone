#!/data/data/com.termux/files/usr/bin/bash

#==============================================================================
#  Database Server Profile
#  Installs: MariaDB, PostgreSQL, Redis, SQLite
#==============================================================================

echo "📦 Installing Database Server profile..."

proot-distro login ubuntu -- bash << 'DB_INSTALL'
#!/bin/bash
set -e

echo "Installing database packages..."

apt update

# SQLite (lightweight, always useful)
apt install -y sqlite3 libsqlite3-dev

# MariaDB (MySQL-compatible)
echo "Installing MariaDB..."
apt install -y mariadb-server mariadb-client

# PostgreSQL
echo "Installing PostgreSQL..."
apt install -y postgresql postgresql-contrib

# Redis
echo "Installing Redis..."
apt install -y redis-server

# Database management tools
apt install -y \
    mycli \
    pgcli \
    redis-tools

# Configure MariaDB
mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

# Create MariaDB config for proot
cat > /etc/mysql/mariadb.conf.d/99-proot.cnf << 'MARIA_CONF'
[mysqld]
user = root
skip-grant-tables
skip-networking = 0
bind-address = 127.0.0.1
MARIA_CONF

# Initialize MariaDB data directory if needed
if [ ! -d "/var/lib/mysql/mysql" ]; then
    mysql_install_db --user=root --datadir=/var/lib/mysql
fi

# Configure PostgreSQL
mkdir -p /var/run/postgresql
chown postgres:postgres /var/run/postgresql

# Create initialization script for databases
cat > /usr/local/bin/init-databases.sh << 'INIT_DB'
#!/bin/bash

echo "Initializing databases..."

# Start MariaDB
mysqld_safe --skip-grant-tables &
sleep 5

# Set up MariaDB root password
mysql -u root << EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY 'rootpassword';
CREATE USER IF NOT EXISTS 'vps'@'localhost' IDENTIFIED BY 'vpspassword';
GRANT ALL PRIVILEGES ON *.* TO 'vps'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

echo "MariaDB configured. User: vps, Password: vpspassword"

# Initialize PostgreSQL if needed
if [ ! -f "/var/lib/postgresql/14/main/PG_VERSION" ]; then
    su - postgres -c "/usr/lib/postgresql/14/bin/initdb -D /var/lib/postgresql/14/main"
fi

echo "PostgreSQL configured."

# Start Redis
redis-server --daemonize yes

echo "Redis started on port 6379"
echo "Database initialization complete!"
INIT_DB

chmod +x /usr/local/bin/init-databases.sh

echo "✓ Database profile installed!"
echo ""
echo "  MariaDB:"
echo "    User: vps / Password: vpspassword"
echo "    Connect: mysql -u vps -pvpspassword"
echo ""
echo "  PostgreSQL:"
echo "    User: postgres"
echo "    Connect: sudo -u postgres psql"
echo ""
echo "  Redis:"
echo "    Port: 6379"
echo "    Connect: redis-cli"
echo ""
echo "  Run 'init-databases.sh' to initialize all databases"
DB_INSTALL

echo "✓ Database Server profile complete!"
