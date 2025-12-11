#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_USER="panovision"
APP_DIR="/var/www/panovision"
NGINX_CONF="/etc/nginx/conf.d/panovision.conf"
SERVICE_NAME="panovision"

echo "=========================================="
echo "PanoVision Installation Script"
echo "=========================================="
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    exit 1
fi

echo "Step 1: Installing system dependencies..."

echo "Installing Node.js 20.x from NodeSource (required for Vite 5)..."
if command -v node &> /dev/null; then
    CURRENT_NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    echo "Current Node.js version: $(node -v)"
    if [ "$CURRENT_NODE_VERSION" -lt "18" ]; then
        echo "Removing old Node.js version..."
        dnf remove -y nodejs npm 2>/dev/null || true
        rm -f /usr/bin/node /usr/bin/npm /usr/local/bin/node /usr/local/bin/npm 2>/dev/null || true
    fi
fi

echo "Adding NodeSource repository..."
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -

echo "Installing Node.js 20.x..."
dnf install -y nodejs

echo "Verifying Node.js installation..."
NODE_VERSION=$(node -v)
NODE_MAJOR_VERSION=$(echo "$NODE_VERSION" | cut -d'v' -f2 | cut -d'.' -f1)
echo "Installed Node.js version: $NODE_VERSION"

if [ "$NODE_MAJOR_VERSION" -lt "18" ]; then
    echo "Error: Node.js 18+ is required for Vite 5. Current version: $NODE_VERSION"
    exit 1
fi

if ! command -v nginx &> /dev/null; then
    dnf install -y nginx
fi

if ! systemctl is-active --quiet firewalld 2>/dev/null; then
    dnf install -y firewalld
fi

echo ""
echo "Step 2: Creating application user..."
if ! id "$APP_USER" &>/dev/null; then
    useradd -r -s /bin/false -d "$APP_DIR" "$APP_USER"
    echo "Created user: $APP_USER"
else
    echo "User $APP_USER already exists"
fi

echo ""
echo "Step 3: Creating application directory..."
mkdir -p "$APP_DIR"
chown -R "$APP_USER:$APP_USER" "$APP_DIR"

echo ""
echo "Step 4: Verifying Node.js version before build..."
NODE_VERSION=$(node -v)
NODE_MAJOR_VERSION=$(echo "$NODE_VERSION" | cut -d'v' -f2 | cut -d'.' -f1)
echo "Using Node.js: $NODE_VERSION"

if [ "$NODE_MAJOR_VERSION" -lt "18" ]; then
    echo "Error: Node.js 18+ is required for Vite 5. Current version: $NODE_VERSION"
    echo "Please run: ./deploy/fix-nodejs.sh"
    exit 1
fi

echo ""
echo "Step 5: Installing Node.js dependencies..."
cd "$PROJECT_DIR"
npm install --production=false

echo ""
echo "Step 6: Building application..."
npm run build

if [ ! -d "$PROJECT_DIR/dist" ]; then
    echo "Error: Build failed - dist directory not found"
    exit 1
fi

echo ""
echo "Step 7: Deploying application files..."
rsync -av --delete "$PROJECT_DIR/dist/" "$APP_DIR/"

NGINX_USER="nginx"
if ! id "$NGINX_USER" &>/dev/null; then
    NGINX_USER="www-data"
fi

chown -R "$NGINX_USER:$NGINX_USER" "$APP_DIR"
find "$APP_DIR" -type d -exec chmod 755 {} \;
find "$APP_DIR" -type f -exec chmod 644 {} \;

echo ""
echo "Step 8: Configuring Nginx..."
cp "$SCRIPT_DIR/nginx-panovision.conf" "$NGINX_CONF"

echo ""
echo "Setting up self-signed SSL certificate..."
SSL_DIR="/etc/ssl/panovision"
mkdir -p "$SSL_DIR"

if [ ! -f "$SSL_DIR/panovision-selfsigned.crt" ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$SSL_DIR/panovision-selfsigned.key" \
        -out "$SSL_DIR/panovision-selfsigned.crt" \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=panovision.officeours.com" 2>/dev/null
    
    chmod 600 "$SSL_DIR/panovision-selfsigned.key"
    chmod 644 "$SSL_DIR/panovision-selfsigned.crt"
    echo "Self-signed certificate created"
else
    echo "Self-signed certificate already exists"
fi

echo ""
echo "Step 9: Testing Nginx configuration..."
nginx -t

echo ""
echo "Step 10: Configuring firewall..."
if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --reload
    echo "Firewall rules configured"
else
    echo "Firewalld is not running, skipping firewall configuration"
fi

echo ""
echo "Step 11: Enabling and starting services..."
systemctl enable nginx
systemctl restart nginx

echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "Application deployed to: $APP_DIR"
echo "Nginx config: $NGINX_CONF"
echo ""
echo "Next steps:"
echo "1. Configure DNS to point panovision.officeours.com to this server"
echo "2. Access: https://panovision.officeours.com (browser will warn about self-signed cert)"
echo ""
echo "To check Nginx status: systemctl status nginx"
echo "To view logs: tail -f /var/log/nginx/panovision-error.log"
echo ""

