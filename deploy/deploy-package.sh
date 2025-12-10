#!/bin/bash

set -e

echo "=========================================="
echo "PanoVision Complete Deployment Package"
echo "=========================================="
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_USER="panovision"
APP_DIR="/var/www/panovision"
NGINX_CONF="/etc/nginx/conf.d/panovision.conf"

echo "Step 1: Installing system dependencies..."

NODE_VERSION_REQUIRED="18"
if command -v node &> /dev/null; then
    CURRENT_NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$CURRENT_NODE_VERSION" -lt "$NODE_VERSION_REQUIRED" ]; then
        echo "Node.js version $CURRENT_NODE_VERSION is too old. Installing Node.js 20.x from NodeSource..."
        dnf remove -y nodejs npm 2>/dev/null || true
        curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
        dnf install -y nodejs
    else
        echo "Node.js version $CURRENT_NODE_VERSION is sufficient"
    fi
else
    echo "Node.js not found. Installing Node.js 20.x from NodeSource..."
    curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
    dnf install -y nodejs
fi

if ! command -v nginx &> /dev/null; then
    dnf install -y nginx
fi

if ! command -v nginx &> /dev/null; then
    dnf install -y nginx
fi

if ! systemctl is-active --quiet firewalld 2>/dev/null; then
    dnf install -y firewalld
    systemctl enable firewalld
    systemctl start firewalld
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
echo "Step 4: Verifying Node.js version..."
NODE_VERSION=$(node -v)
echo "Using Node.js: $NODE_VERSION"
NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_MAJOR" -lt "18" ]; then
    echo "Error: Node.js 18+ is required for Vite 5. Current version: $NODE_VERSION"
    exit 1
fi

echo ""
echo "Step 5: Installing Node.js dependencies..."
cd "$PROJECT_DIR"
npm install --legacy-peer-deps 2>/dev/null || npm install

echo ""
echo "Step 6: Building application..."
npm run build

if [ ! -d "$PROJECT_DIR/dist" ]; then
    echo "Error: Build failed - dist directory not found"
    echo "Checking for build errors..."
    exit 1
fi

echo ""
echo "Step 7: Deploying application files..."
rsync -av --delete "$PROJECT_DIR/dist/" "$APP_DIR/" 2>/dev/null || cp -r "$PROJECT_DIR/dist/"* "$APP_DIR/"
chown -R "$APP_USER:$APP_USER" "$APP_DIR"
chmod -R 755 "$APP_DIR"

echo ""
echo "Step 8: Configuring Nginx..."
cp "$SCRIPT_DIR/nginx-panovision.conf" "$NGINX_CONF"

if [ ! -f "/etc/letsencrypt/live/panovision.officeours.com/fullchain.pem" ]; then
    echo ""
    echo "SSL certificate not found. Setting up temporary self-signed certificate..."
    
    SSL_DIR="/etc/ssl/panovision"
    mkdir -p "$SSL_DIR"
    
    if [ ! -f "$SSL_DIR/panovision-selfsigned.crt" ]; then
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$SSL_DIR/panovision-selfsigned.key" \
            -out "$SSL_DIR/panovision-selfsigned.crt" \
            -subj "/C=US/ST=State/L=City/O=Organization/CN=panovision.officeours.com" 2>/dev/null
        
        chmod 600 "$SSL_DIR/panovision-selfsigned.key"
        chmod 644 "$SSL_DIR/panovision-selfsigned.crt"
    fi
    
    sed -i "s|/etc/letsencrypt/live/panovision.officeours.com/fullchain.pem|$SSL_DIR/panovision-selfsigned.crt|g" "$NGINX_CONF"
    sed -i "s|/etc/letsencrypt/live/panovision.officeours.com/privkey.pem|$SSL_DIR/panovision-selfsigned.key|g" "$NGINX_CONF"
    
    echo ""
    echo "Note: Using self-signed certificate. For production, run:"
    echo "  certbot --nginx -d panovision.officeours.com"
fi

echo ""
echo "Step 9: Testing Nginx configuration..."
if nginx -t 2>/dev/null; then
    echo "Nginx configuration is valid"
else
    echo "Warning: Nginx configuration test failed, but continuing..."
fi

echo ""
echo "Step 10: Configuring firewall..."
if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-service=http 2>/dev/null || true
    firewall-cmd --permanent --add-service=https 2>/dev/null || true
    firewall-cmd --reload 2>/dev/null || true
    echo "Firewall rules configured"
else
    echo "Firewalld is not running, skipping firewall configuration"
fi

echo ""
echo "Step 11: Enabling and starting services..."
systemctl enable nginx 2>/dev/null || true
systemctl restart nginx 2>/dev/null || systemctl start nginx

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Application deployed to: $APP_DIR"
echo "Nginx config: $NGINX_CONF"
echo ""
echo "Verifying deployment..."
sleep 2

if systemctl is-active --quiet nginx; then
    echo "✓ Nginx is running"
else
    echo "✗ Nginx is not running - check logs: journalctl -u nginx"
fi

if [ -f "$APP_DIR/index.html" ]; then
    echo "✓ Application files deployed"
else
    echo "✗ Application files not found"
fi

echo ""
echo "Next steps:"
echo "1. Configure DNS: panovision.officeours.com -> $(hostname -I | awk '{print $1}')"
echo "2. Get SSL certificate: certbot --nginx -d panovision.officeours.com"
echo "3. Access: https://panovision.officeours.com"
echo ""
echo "View logs: tail -f /var/log/nginx/panovision-error.log"
echo ""

