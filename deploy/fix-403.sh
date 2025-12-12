#!/bin/bash

echo "=========================================="
echo "PanoVision 403 Permission Fix Script"
echo "=========================================="
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    exit 1
fi

APP_DIR="/var/www/panovision"

echo "Detecting Nginx user..."
NGINX_USER="nginx"
if ! id "$NGINX_USER" &>/dev/null; then
    NGINX_USER="www-data"
    if ! id "$NGINX_USER" &>/dev/null; then
        echo "Error: Could not find nginx or www-data user"
        echo "Nginx user from process:"
        ps aux | grep nginx | grep -v grep | head -1 | awk '{print $1}'
        exit 1
    fi
fi

echo "Using Nginx user: $NGINX_USER"
echo ""

echo "Fixing file ownership..."
chown -R "$NGINX_USER:$NGINX_USER" "$APP_DIR"

echo "Fixing directory permissions (755)..."
find "$APP_DIR" -type d -exec chmod 755 {} \;

echo "Fixing file permissions (644)..."
find "$APP_DIR" -type f -exec chmod 644 {} \;

echo ""
echo "Verifying permissions..."
ls -ld "$APP_DIR"
ls -l "$APP_DIR/index.html" 2>/dev/null || echo "index.html not found"

echo ""
echo "Checking SELinux context (if applicable)..."
if command -v getenforce &>/dev/null; then
    SELINUX_STATUS=$(getenforce)
    echo "SELinux status: $SELINUX_STATUS"
    if [ "$SELINUX_STATUS" != "Disabled" ]; then
        echo "Setting SELinux context for web content..."
        chcon -R -t httpd_sys_content_t "$APP_DIR" 2>/dev/null || echo "SELinux context update skipped"
    fi
fi

echo ""
echo "=========================================="
echo "Permission fix complete!"
echo "=========================================="
echo ""
echo "Reloading Nginx..."
systemctl reload nginx

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
else
    SERVER_URL="${SERVER_URL:-panovision.example.com}"
fi

echo ""
echo "Test the site: https://$SERVER_URL"
echo ""

