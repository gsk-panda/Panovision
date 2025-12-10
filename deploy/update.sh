#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_USER="panovision"
APP_DIR="/var/www/panovision"

echo "=========================================="
echo "PanoVision Update Script"
echo "=========================================="
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    exit 1
fi

echo "Step 1: Updating dependencies..."
cd "$PROJECT_DIR"
npm install --production=false

echo ""
echo "Step 2: Building application..."
npm run build

if [ ! -d "$PROJECT_DIR/dist" ]; then
    echo "Error: Build failed - dist directory not found"
    exit 1
fi

echo ""
echo "Step 3: Deploying updated files..."
rsync -av --delete "$PROJECT_DIR/dist/" "$APP_DIR/"

NGINX_USER="nginx"
if ! id "$NGINX_USER" &>/dev/null; then
    NGINX_USER="www-data"
fi

chown -R "$NGINX_USER:$NGINX_USER" "$APP_DIR"
find "$APP_DIR" -type d -exec chmod 755 {} \;
find "$APP_DIR" -type f -exec chmod 644 {} \;

echo ""
echo "Step 4: Reloading Nginx..."
systemctl reload nginx

echo ""
echo "=========================================="
echo "Update Complete!"
echo "=========================================="
echo ""

