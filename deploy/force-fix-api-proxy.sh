#!/bin/bash

set -e

if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    exit 1
fi

PROJECT_DIR="/opt/Panovision"
API_PROXY_FILE="$PROJECT_DIR/deploy/api-proxy.js"
API_PROXY_DIR="$PROJECT_DIR/deploy"

echo "=========================================="
echo "Force Fixing API Proxy Permissions"
echo "=========================================="
echo ""

echo "1. Stopping API proxy service..."
systemctl stop api-proxy 2>/dev/null || true
sleep 1

echo ""
echo "2. Checking current permissions..."
if [ -f "$API_PROXY_FILE" ]; then
    echo "File exists: $API_PROXY_FILE"
    ls -la "$API_PROXY_FILE"
    echo ""
    
    CURRENT_OWNER=$(stat -c '%U:%G' "$API_PROXY_FILE")
    CURRENT_PERMS=$(stat -c '%a' "$API_PROXY_FILE")
    
    echo "Current owner: $CURRENT_OWNER"
    echo "Current permissions: $CURRENT_PERMS"
else
    echo "✗ ERROR: API proxy file not found: $API_PROXY_FILE"
    exit 1
fi

echo ""
echo "3. Fixing directory permissions..."
if [ -d "$API_PROXY_DIR" ]; then
    chmod 755 "$API_PROXY_DIR"
    chown panovision:panovision "$API_PROXY_DIR"
    echo "✓ Directory permissions set: 755, owner: panovision:panovision"
    ls -ld "$API_PROXY_DIR"
else
    echo "✗ ERROR: Directory not found: $API_PROXY_DIR"
    exit 1
fi

echo ""
echo "4. Fixing file permissions..."
chmod 644 "$API_PROXY_FILE"
chown panovision:panovision "$API_PROXY_FILE"
echo "✓ File permissions set: 644 (readable by all), owner: panovision:panovision"
ls -la "$API_PROXY_FILE"

echo ""
echo "4a. Testing if panovision user can read it..."
if sudo -u panovision test -r "$API_PROXY_FILE"; then
    echo "✓ panovision user can read with 644"
else
    echo "✗ panovision user cannot read with 644, trying 755..."
    chmod 755 "$API_PROXY_FILE"
    if sudo -u panovision test -r "$API_PROXY_FILE"; then
        echo "✓ panovision user can read with 755"
    else
        echo "✗ Still cannot read - will try more aggressive fixes"
        chmod 755 "$API_PROXY_DIR"
        chmod 644 "$API_PROXY_FILE"
    fi
    ls -la "$API_PROXY_FILE"
fi

echo ""
echo "5. Verifying panovision user can read the file..."
if sudo -u panovision test -r "$API_PROXY_FILE"; then
    echo "✓ panovision user can read the file"
else
    echo "✗ panovision user CANNOT read the file"
    echo "Trying more permissive permissions..."
    chmod 644 "$API_PROXY_FILE"
    if sudo -u panovision test -r "$API_PROXY_FILE"; then
        echo "✓ panovision user can now read with 644 permissions"
    else
        echo "✗ Still cannot read - checking SELinux..."
    fi
fi

echo ""
echo "6. Checking and fixing SELinux context..."
if command -v getenforce &>/dev/null; then
    SELINUX_STATUS=$(getenforce)
    echo "SELinux status: $SELINUX_STATUS"
    
    if [ "$SELINUX_STATUS" != "Disabled" ]; then
        echo "Setting SELinux context..."
        
        CURRENT_CONTEXT=$(ls -Z "$API_PROXY_FILE" 2>/dev/null | awk '{print $4}' | cut -d: -f3 || echo "unknown")
        echo "Current SELinux context type: $CURRENT_CONTEXT"
        
        chcon -t bin_t "$API_PROXY_FILE" 2>/dev/null || {
            echo "Failed to set bin_t, trying other contexts..."
            chcon -t exec_t "$API_PROXY_FILE" 2>/dev/null || {
                echo "Failed to set exec_t, trying httpd_exec_t..."
                chcon -t httpd_exec_t "$API_PROXY_FILE" 2>/dev/null || {
                    echo "Warning: Could not set SELinux context"
                }
            }
        }
        
        NEW_CONTEXT=$(ls -Z "$API_PROXY_FILE" 2>/dev/null | awk '{print $4}' | cut -d: -f3 || echo "unknown")
        echo "New SELinux context type: $NEW_CONTEXT"
        
        if sudo -u panovision test -r "$API_PROXY_FILE"; then
            echo "✓ File is readable after SELinux context change"
        else
            echo "✗ File still not readable - may need SELinux boolean"
            setsebool -P httpd_read_user_content 1 2>/dev/null || true
        fi
    else
        echo "SELinux is disabled, skipping context setting"
    fi
else
    echo "SELinux tools not found, skipping"
fi

echo ""
echo "7. Final verification..."
FINAL_OWNER=$(stat -c '%U:%G' "$API_PROXY_FILE")
FINAL_PERMS=$(stat -c '%a' "$API_PROXY_FILE")

echo "Final owner: $FINAL_OWNER"
echo "Final permissions: $FINAL_PERMS"

if [ "$FINAL_OWNER" = "panovision:panovision" ] && [ "$FINAL_PERMS" = "755" ] || [ "$FINAL_PERMS" = "644" ]; then
    echo "✓ Permissions look correct"
else
    echo "⚠ Permissions may still be incorrect"
fi

echo ""
echo "8. Testing file access as panovision user..."
if sudo -u panovision node --version >/dev/null 2>&1; then
    echo "Node.js is accessible to panovision user"
    
    if sudo -u panovision test -f "$API_PROXY_FILE"; then
        echo "✓ File exists"
    else
        echo "✗ File is not accessible"
    fi
    
    echo "Testing if panovision user can actually read and execute the file..."
    if sudo -u panovision /usr/bin/node "$API_PROXY_FILE" --help >/dev/null 2>&1 || \
       timeout 2 sudo -u panovision /usr/bin/node "$API_PROXY_FILE" >/dev/null 2>&1; then
        echo "✓ panovision user can read and execute the file"
    else
        echo "✗ panovision user CANNOT read/execute the file"
        echo ""
        echo "Trying more permissive approach..."
        chmod 644 "$API_PROXY_FILE"
        chmod 755 "$API_PROXY_DIR"
        
        if sudo -u panovision test -r "$API_PROXY_FILE"; then
            echo "✓ File is now readable with 644 permissions"
        else
            echo "✗ File still not readable - checking ACLs and extended attributes..."
            getfacl "$API_PROXY_FILE" 2>/dev/null || echo "ACLs not available"
            lsattr "$API_PROXY_FILE" 2>/dev/null || echo "Extended attributes not available"
        fi
    fi
else
    echo "⚠ Could not test Node.js access"
fi

echo ""
echo "9. Checking service file configuration..."
SERVICE_FILE="/etc/systemd/system/api-proxy.service"
if [ -f "$SERVICE_FILE" ]; then
    echo "Service file contents:"
    cat "$SERVICE_FILE"
    echo ""
    
    if grep -q "/opt/panovision" "$SERVICE_FILE"; then
        echo "✗ Service file has wrong path (/opt/panovision instead of /opt/Panovision)"
        echo "Fixing service file..."
        sed -i "s|/opt/panovision|/opt/Panovision|g" "$SERVICE_FILE"
        echo "✓ Service file updated"
        echo "New service file contents:"
        cat "$SERVICE_FILE"
    else
        echo "✓ Service file has correct path"
    fi
    
    if grep -q "WorkingDirectory=/opt/panovision" "$SERVICE_FILE"; then
        echo "✗ WorkingDirectory is wrong"
        sed -i "s|WorkingDirectory=/opt/panovision|WorkingDirectory=/opt/Panovision/deploy|g" "$SERVICE_FILE"
        echo "✓ WorkingDirectory fixed"
    fi
fi

echo ""
echo "10. Starting API proxy service..."
systemctl daemon-reload
systemctl start api-proxy

sleep 3

if systemctl is-active --quiet api-proxy; then
    echo "✓ API proxy service started successfully!"
    echo ""
    echo "Service status:"
    systemctl status api-proxy --no-pager -l | head -20
else
    echo "✗ API proxy service failed to start"
    echo ""
    echo "Recent logs:"
    journalctl -u api-proxy -n 30 --no-pager
    echo ""
    echo "File permissions:"
    ls -la "$API_PROXY_FILE"
    echo ""
    echo "Directory permissions:"
    ls -ld "$API_PROXY_DIR"
    echo ""
    echo "SELinux context:"
    ls -Z "$API_PROXY_FILE" 2>/dev/null || echo "SELinux not available"
fi
