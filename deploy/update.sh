#!/bin/bash

set -e

# PanoVision Update Script
# Updates the application with latest code from git repository

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ ! -d "$PROJECT_DIR/.git" ]; then
    echo "Error: Not a git repository. Cannot update."
    echo "If you installed from a tarball, you'll need to reinstall."
    exit 1
fi

APP_DIR="/var/www/panovision"

echo "=========================================="
echo "PanoVision Update Script"
echo "=========================================="
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "Warning: Some operations require root privileges."
    echo "You may need to run parts of this script with sudo."
    echo ""
fi

echo "Step 1: Pulling latest code from repository..."
cd "$PROJECT_DIR"
git pull

if [ $? -ne 0 ]; then
    echo "Error: Failed to pull latest code"
    exit 1
fi

echo "✓ Code updated"
echo ""

echo "Step 2: Installing/updating dependencies..."
npm install --production=false

if [ $? -ne 0 ]; then
    echo "Error: Failed to install dependencies"
    exit 1
fi

echo "✓ Dependencies updated"
echo ""

echo "Step 3: Building application..."
export NODE_OPTIONS="--openssl-legacy-provider"

# Load environment variables if .env exists
if [ -f "$PROJECT_DIR/.env" ]; then
    export $(grep -v '^#' "$PROJECT_DIR/.env" | xargs)
fi

npm run build

if [ $? -ne 0 ]; then
    echo "Error: Build failed"
    exit 1
fi

if [ ! -d "$PROJECT_DIR/dist" ]; then
    echo "Error: Build failed - dist directory not found"
    exit 1
fi

echo "✓ Build completed"
echo ""

echo "Step 4: Deploying files..."
if [ "$EUID" -eq 0 ]; then
    rsync -av --delete "$PROJECT_DIR/dist/" "$APP_DIR/"
    chown -R panovision:panovision "$APP_DIR"
else
    sudo rsync -av --delete "$PROJECT_DIR/dist/" "$APP_DIR/"
    sudo chown -R panovision:panovision "$APP_DIR"
fi

echo "✓ Files deployed"
echo ""

echo "Step 5: Restarting API proxy service..."
if [ "$EUID" -eq 0 ]; then
    systemctl restart api-proxy
else
    sudo systemctl restart api-proxy
fi

sleep 2

if systemctl is-active --quiet api-proxy; then
    echo "✓ API proxy restarted"
else
    echo "⚠ Warning: API proxy may have issues. Check logs: journalctl -u api-proxy"
fi

echo ""

echo "Step 6: Reloading Apache..."
if [ "$EUID" -eq 0 ]; then
    systemctl reload httpd
else
    sudo systemctl reload httpd
fi

echo "✓ Apache reloaded"
echo ""

echo "=========================================="
echo "Update Complete!"
echo "=========================================="
echo ""
echo "Application has been updated and services restarted."
echo ""
echo "To verify:"
echo "  1. Check Apache status: systemctl status httpd"
echo "  2. Check API proxy status: systemctl status api-proxy"
echo "  3. Access the application: https://your-server-url/logs"
echo ""
