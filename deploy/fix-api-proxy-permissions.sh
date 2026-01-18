#!/bin/bash

set -e

if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    exit 1
fi

PROJECT_DIR="/opt/Panovision"

if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: Project directory not found: $PROJECT_DIR"
    exit 1
fi

echo "Fixing API proxy service permissions..."

echo "Setting correct ownership and permissions..."

if [ -d "$PROJECT_DIR/deploy" ]; then
    chmod 755 "$PROJECT_DIR/deploy"
    chown panovision:panovision "$PROJECT_DIR/deploy" 2>/dev/null || {
        echo "Warning: Could not change deploy directory ownership"
    }
fi

if [ -f "$PROJECT_DIR/deploy/api-proxy.js" ]; then
    chmod 755 "$PROJECT_DIR/deploy/api-proxy.js"
    chown panovision:panovision "$PROJECT_DIR/deploy/api-proxy.js"
    echo "✓ Permissions set for api-proxy.js"
else
    echo "✗ api-proxy.js not found at $PROJECT_DIR/deploy/api-proxy.js"
    exit 1
fi

if command -v getenforce &>/dev/null && [ "$(getenforce)" != "Disabled" ]; then
    echo "Setting SELinux context..."
    chcon -R -t bin_t "$PROJECT_DIR/deploy/api-proxy.js" 2>/dev/null || {
        echo "Warning: Could not set SELinux context"
    }
fi

echo "Verifying permissions..."
ls -la "$PROJECT_DIR/deploy/api-proxy.js"

echo ""
echo "Restarting API proxy service..."
systemctl daemon-reload
systemctl restart api-proxy

sleep 2

if systemctl is-active --quiet api-proxy; then
    echo "✓ API proxy service is running"
else
    echo "⚠ API proxy service failed to start"
    echo "Check logs with: journalctl -u api-proxy -n 50"
fi
