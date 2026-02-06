#!/data/data/com.termux/files/usr/bin/bash

#==============================================================================
#  Web Hosting Profile
#  Installs: Nginx, PHP, SSL support, static site hosting
#==============================================================================

echo "📦 Installing Web Hosting profile..."

proot-distro login ubuntu -- bash << 'WEB_INSTALL'
#!/bin/bash
set -e

echo "Installing web hosting packages..."

apt update

# Web server
apt install -y \
    nginx

# PHP and extensions
apt install -y \
    php-fpm \
    php-cli \
    php-common \
    php-mysql \
    php-pgsql \
    php-sqlite3 \
    php-curl \
    php-gd \
    php-mbstring \
    php-xml \
    php-json \
    php-zip \
    php-bcmath \
    php-intl

# SSL tools
apt install -y \
    certbot \
    python3-certbot-nginx \
    openssl

# Utilities
apt install -y \
    sqlite3

# Configure Nginx
mkdir -p /var/www/html
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled

# Create default site
cat > /var/www/html/index.html << 'WELCOME_PAGE'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>VPS-on-Phone</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', system-ui, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #fff;
        }
        .container {
            text-align: center;
            padding: 2rem;
        }
        .logo {
            font-size: 4rem;
            margin-bottom: 1rem;
        }
        h1 {
            font-size: 2.5rem;
            margin-bottom: 0.5rem;
            background: linear-gradient(90deg, #00d9ff, #00ff88);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        p {
            font-size: 1.2rem;
            opacity: 0.8;
            margin-bottom: 2rem;
        }
        .status {
            display: inline-block;
            padding: 0.5rem 1.5rem;
            background: rgba(0, 255, 136, 0.2);
            border: 1px solid #00ff88;
            border-radius: 50px;
            color: #00ff88;
        }
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
WELCOME_PAGE

# Create nginx config
cat > /etc/nginx/sites-available/default << 'NGINX_CONF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/html;
    index index.html index.htm index.php;
    
    server_name _;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
NGINX_CONF

echo "✓ Web hosting profile installed!"
echo "  Web root: /var/www/html"
echo "  Nginx config: /etc/nginx/sites-available/default"
WEB_INSTALL

echo "✓ Web Hosting profile complete!"
