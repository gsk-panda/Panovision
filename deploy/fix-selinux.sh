#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
else
    SERVER_URL="${SERVER_URL:-panovision.example.com}"
fi

echo "=========================================="
echo "Fixing SELinux for Nginx Proxy"
echo "=========================================="
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    exit 1
fi

echo "Step 1: Checking SELinux status..."
if command -v getenforce &>/dev/null; then
    SELINUX_STATUS=$(getenforce)
    echo "SELinux status: $SELINUX_STATUS"
    
    if [ "$SELINUX_STATUS" = "Disabled" ]; then
        echo "SELinux is disabled, this is not a SELinux issue"
        exit 0
    fi
    
    echo ""
    echo "Step 2: Setting SELinux boolean to allow Nginx network connections..."
    setsebool -P httpd_can_network_connect 1
    
    if getsebool httpd_can_network_connect | grep -q "on$"; then
        echo "✓ SELinux boolean set successfully"
    else
        echo "✗ Failed to set SELinux boolean"
        exit 1
    fi
    
    echo ""
    echo "Step 3: Verifying the setting..."
    getsebool httpd_can_network_connect
    
    echo ""
    echo "Step 4: Reloading Nginx..."
    systemctl reload nginx
    
    echo ""
    echo "=========================================="
    echo "SELinux Fix Complete!"
    echo "=========================================="
    echo ""
    echo "The proxy should now work. Test it:"
    echo "  curl -k 'https://$SERVER_URL/api/panorama?type=log&log-type=traffic&key=TEST&nlogs=1'"
    echo ""
else
    echo "SELinux tools not found. This might not be a SELinux issue."
    echo "The error 'Permission denied (13)' typically indicates SELinux blocking network connections."
fi

