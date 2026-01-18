#!/bin/bash

if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    exit 1
fi

API_PROXY_FILE="/opt/Panovision/deploy/api-proxy.js"

echo "Testing API proxy file access..."
echo ""

echo "1. As root:"
if /usr/bin/node "$API_PROXY_FILE" --version >/dev/null 2>&1 || timeout 1 /usr/bin/node "$API_PROXY_FILE" >/dev/null 2>&1; then
    echo "✓ Root can access the file"
else
    echo "✗ Root cannot access the file"
fi

echo ""
echo "2. As panovision user:"
if sudo -u panovision /usr/bin/node "$API_PROXY_FILE" --version >/dev/null 2>&1 || timeout 1 sudo -u panovision /usr/bin/node "$API_PROXY_FILE" >/dev/null 2>&1; then
    echo "✓ panovision user can access the file"
else
    echo "✗ panovision user CANNOT access the file"
    echo ""
    echo "Current permissions:"
    ls -la "$API_PROXY_FILE"
    echo ""
    echo "Directory permissions:"
    ls -ld "$(dirname "$API_PROXY_FILE")"
    echo ""
    echo "SELinux context:"
    ls -Z "$API_PROXY_FILE" 2>/dev/null || echo "SELinux not available"
    echo ""
    echo "Testing read access:"
    sudo -u panovision test -r "$API_PROXY_FILE" && echo "✓ Readable" || echo "✗ NOT readable"
    echo ""
    echo "Testing execute access:"
    sudo -u panovision test -x "$API_PROXY_FILE" && echo "✓ Executable" || echo "✗ NOT executable"
fi
