#!/bin/bash

set -e

if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    exit 1
fi

API_PROXY_FILE="/opt/Panovision/deploy/api-proxy.js"
API_PROXY_DIR="/opt/Panovision/deploy"

echo "=========================================="
echo "Comprehensive API Proxy Diagnosis"
echo "=========================================="
echo ""

echo "1. Checking if panovision user exists..."
if id panovision >/dev/null 2>&1; then
    echo "✓ panovision user exists"
    id panovision
else
    echo "✗ panovision user does NOT exist"
    echo "Creating panovision user..."
    useradd -r -s /bin/false -d /opt/Panovision panovision
fi

echo ""
echo "2. Checking file existence and basic info..."
if [ -f "$API_PROXY_FILE" ]; then
    echo "✓ File exists"
    ls -la "$API_PROXY_FILE"
    file "$API_PROXY_FILE"
else
    echo "✗ File does NOT exist"
    exit 1
fi

echo ""
echo "3. Checking directory permissions..."
ls -ld "$API_PROXY_DIR"
ls -la "$API_PROXY_DIR" | head -10

echo ""
echo "4. Checking file permissions in detail..."
stat "$API_PROXY_FILE"

echo ""
echo "5. Checking for extended attributes and ACLs..."
getfattr -d "$API_PROXY_FILE" 2>/dev/null || echo "No extended attributes"
getfacl "$API_PROXY_FILE" 2>/dev/null || echo "No ACLs"

echo ""
echo "6. Checking for immutable flags..."
lsattr "$API_PROXY_FILE" 2>/dev/null || echo "Extended attributes not available"

echo ""
echo "7. Testing as root..."
if /usr/bin/node "$API_PROXY_FILE" --version >/dev/null 2>&1 || timeout 1 /usr/bin/node "$API_PROXY_FILE" >/dev/null 2>&1; then
    echo "✓ Root can access the file"
else
    echo "✗ Root cannot access the file"
fi

echo ""
echo "8. Testing as panovision user..."
if sudo -u panovision test -r "$API_PROXY_FILE" 2>&1; then
    echo "✓ panovision user can read the file (test -r)"
else
    echo "✗ panovision user CANNOT read the file (test -r)"
    echo "Error: $(sudo -u panovision test -r "$API_PROXY_FILE" 2>&1 || true)"
fi

if sudo -u panovision test -x "$API_PROXY_DIR" 2>&1; then
    echo "✓ panovision user can access the directory"
else
    echo "✗ panovision user CANNOT access the directory"
    echo "Error: $(sudo -u panovision test -x "$API_PROXY_DIR" 2>&1 || true)"
fi

echo ""
echo "9. Testing actual Node.js execution as panovision..."
if timeout 2 sudo -u panovision /usr/bin/node "$API_PROXY_FILE" >/dev/null 2>&1; then
    echo "✓ panovision user can execute with Node.js"
else
    EXIT_CODE=$?
    echo "✗ panovision user CANNOT execute with Node.js (exit code: $EXIT_CODE)"
    echo "Trying with verbose output..."
    timeout 2 sudo -u panovision /usr/bin/node "$API_PROXY_FILE" 2>&1 | head -5 || true
fi

echo ""
echo "10. Checking service file..."
SERVICE_FILE="/etc/systemd/system/api-proxy.service"
if [ -f "$SERVICE_FILE" ]; then
    echo "Service file contents:"
    cat "$SERVICE_FILE"
    echo ""
    
    SERVICE_USER=$(grep "^User=" "$SERVICE_FILE" | cut -d= -f2 || echo "not set")
    SERVICE_GROUP=$(grep "^Group=" "$SERVICE_FILE" | cut -d= -f2 || echo "not set")
    SERVICE_WD=$(grep "^WorkingDirectory=" "$SERVICE_FILE" | cut -d= -f2 || echo "not set")
    
    echo "Service User: $SERVICE_USER"
    echo "Service Group: $SERVICE_GROUP"
    echo "Working Directory: $SERVICE_WD"
    
    if [ "$SERVICE_WD" != "not set" ] && [ ! -d "$SERVICE_WD" ]; then
        echo "✗ WorkingDirectory does not exist: $SERVICE_WD"
    fi
else
    echo "✗ Service file not found"
fi

echo ""
echo "11. Checking systemd capabilities..."
if systemctl show api-proxy | grep -q "User="; then
    echo "Service user from systemd:"
    systemctl show api-proxy | grep "User="
fi

echo ""
echo "12. Checking for AppArmor (alternative to SELinux)..."
if command -v aa-status &>/dev/null; then
    aa-status 2>/dev/null | head -5 || echo "AppArmor not active"
else
    echo "AppArmor not installed"
fi

echo ""
echo "=========================================="
echo "Diagnosis Complete"
echo "=========================================="
echo ""
echo "If panovision user cannot read the file, try:"
echo "  1. chmod 644 $API_PROXY_FILE"
echo "  2. chmod 755 $API_PROXY_DIR"
echo "  3. chown panovision:panovision $API_PROXY_FILE"
echo "  4. chown panovision:panovision $API_PROXY_DIR"
echo ""
echo "If still not working, consider running service as root:"
echo "  sudo ./deploy/run-api-proxy-as-root.sh"
