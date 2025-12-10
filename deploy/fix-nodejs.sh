#!/bin/bash

set -e

echo "=========================================="
echo "Node.js Version Fix Script"
echo "=========================================="
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    exit 1
fi

echo "Checking current Node.js version..."
if command -v node &> /dev/null; then
    CURRENT_VERSION=$(node -v)
    echo "Current version: $CURRENT_VERSION"
    NODE_MAJOR=$(echo "$CURRENT_VERSION" | cut -d'v' -f2 | cut -d'.' -f1)
    
    if [ "$NODE_MAJOR" -ge "18" ]; then
        echo "Node.js version is sufficient (18+). No changes needed."
        exit 0
    fi
    
    echo "Node.js version is too old. Upgrading to Node.js 20.x..."
else
    echo "Node.js not found. Installing Node.js 20.x..."
fi

echo ""
echo "Removing old Node.js installation (if any)..."
dnf remove -y nodejs npm 2>/dev/null || true

echo ""
echo "Adding NodeSource repository..."
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -

echo ""
echo "Installing Node.js 20.x..."
dnf install -y nodejs

echo ""
echo "Verifying installation..."
NEW_VERSION=$(node -v)
echo "New Node.js version: $NEW_VERSION"

NODE_MAJOR=$(echo "$NEW_VERSION" | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_MAJOR" -lt "18" ]; then
    echo "Error: Failed to install Node.js 18+"
    exit 1
fi

echo ""
echo "=========================================="
echo "Node.js upgrade complete!"
echo "=========================================="
echo ""
echo "You can now run the build:"
echo "  cd /opt/panovision"
echo "  npm install"
echo "  npm run build"
echo ""

