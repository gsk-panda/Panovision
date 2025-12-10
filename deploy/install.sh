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
dnf install -y nodejs npm nginx firewalld

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
echo "Step 4: Installing Node.js dependencies..."
cd "$PROJECT_DIR"
npm install --production=false

echo ""
echo "Step 5: Building application..."
npm run build

if [ ! -d "$PROJECT_DIR/dist" ]; then
    echo "Error: Build failed - dist directory not found"
    exit 1
fi

echo ""
echo "Step 6: Deploying application files..."
rsync -av --delete "$PROJECT_DIR/dist/" "$APP_DIR/"
chown -R "$APP_USER:$APP_USER" "$APP_DIR"

echo ""
echo "Step 7: Configuring Nginx..."
cp "$SCRIPT_DIR/nginx-panovision.conf" "$NGINX_CONF"

if [ ! -f "/etc/letsencrypt/live/panovision.officeours.com/fullchain.pem" ]; then
    echo ""
    echo "Warning: SSL certificate not found. Installing certbot..."
    dnf install -y certbot python3-certbot-nginx
    
    echo ""
    echo "=========================================="
    echo "SSL Certificate Setup Required"
    echo "=========================================="
    echo "You need to obtain an SSL certificate for panovision.officeours.com"
    echo "Run the following command after DNS is configured:"
    echo ""
    echo "  certbot --nginx -d panovision.officeours.com"
    echo ""
    echo "For now, the Nginx config will use a self-signed certificate."
    echo "Updating Nginx config to use temporary self-signed cert..."
    
    if [ ! -f "/etc/ssl/certs/panovision-selfsigned.crt" ]; then
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /etc/ssl/private/panovision-selfsigned.key \
            -out /etc/ssl/certs/panovision-selfsigned.crt \
            -subj "/CN=panovision.officeours.com"
    fi
    
    sed -i 's|/etc/letsencrypt/live/panovision.officeours.com/fullchain.pem|/etc/ssl/certs/panovision-selfsigned.crt|g' "$NGINX_CONF"
    sed -i 's|/etc/letsencrypt/live/panovision.officeours.com/privkey.pem|/etc/ssl/private/panovision-selfsigned.key|g' "$NGINX_CONF"
fi

echo ""
echo "Step 8: Testing Nginx configuration..."
nginx -t

echo ""
echo "Step 9: Configuring firewall..."
if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --reload
    echo "Firewall rules configured"
else
    echo "Firewalld is not running, skipping firewall configuration"
fi

echo ""
echo "Step 10: Enabling and starting services..."
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
echo "2. If using Let's Encrypt, run: certbot --nginx -d panovision.officeours.com"
echo "3. Verify the site is accessible at https://panovision.officeours.com"
echo ""
echo "To check Nginx status: systemctl status nginx"
echo "To view logs: tail -f /var/log/nginx/panovision-error.log"
echo ""

