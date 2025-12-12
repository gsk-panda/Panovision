#!/bin/bash

echo "=========================================="
echo "Fixing 502 Bad Gateway on RHEL 9.7"
echo "=========================================="
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    exit 1
fi

# Detect project directory
if [ -d "/opt/New-Panovision" ]; then
    PROJECT_DIR="/opt/New-Panovision"
elif [ -d "/opt/panovision" ]; then
    PROJECT_DIR="/opt/panovision"
else
    echo "Error: Cannot find project directory"
    exit 1
fi

echo "Using project directory: $PROJECT_DIR"
echo ""

echo "Step 1: Checking API proxy service status..."
if systemctl is-active --quiet api-proxy; then
    echo "✓ API proxy service is running"
    systemctl status api-proxy --no-pager -l | head -10
else
    echo "✗ API proxy service is NOT running"
fi
echo ""

echo "Step 2: Checking service file configuration..."
if [ -f /etc/systemd/system/api-proxy.service ]; then
    echo "Service file contents:"
    cat /etc/systemd/system/api-proxy.service
    echo ""
    
    # Check if paths are correct
    if grep -q "/opt/panovision" /etc/systemd/system/api-proxy.service && [ "$PROJECT_DIR" != "/opt/panovision" ]; then
        echo "⚠ Warning: Service file has incorrect paths"
        echo "Updating service file..."
        
        # Backup original
        cp /etc/systemd/system/api-proxy.service /etc/systemd/system/api-proxy.service.bak
        
        # Update paths
        sed "s|/opt/panovision|$PROJECT_DIR|g" /etc/systemd/system/api-proxy.service.bak > /etc/systemd/system/api-proxy.service
        echo "✓ Service file updated"
    fi
else
    echo "✗ Service file not found"
    if [ -f "$PROJECT_DIR/deploy/api-proxy.service" ]; then
        echo "Creating service file from template..."
        sed "s|/opt/panovision|$PROJECT_DIR|g" "$PROJECT_DIR/deploy/api-proxy.service" > /etc/systemd/system/api-proxy.service
        systemctl daemon-reload
        echo "✓ Service file created"
    fi
fi
echo ""

echo "Step 3: Checking API proxy file exists..."
if [ -f "$PROJECT_DIR/deploy/api-proxy.js" ]; then
    echo "✓ API proxy file exists at $PROJECT_DIR/deploy/api-proxy.js"
    ls -l "$PROJECT_DIR/deploy/api-proxy.js"
else
    echo "✗ API proxy file not found at $PROJECT_DIR/deploy/api-proxy.js"
    exit 1
fi
echo ""

echo "Step 4: Checking Node.js..."
if command -v node &> /dev/null; then
    NODE_PATH=$(which node)
    NODE_VERSION=$(node -v)
    echo "✓ Node.js found: $NODE_PATH ($NODE_VERSION)"
    
    # Check if service file uses correct node path
    SERVICE_NODE=$(grep "^ExecStart=" /etc/systemd/system/api-proxy.service | cut -d'=' -f2 | cut -d' ' -f1)
    if [ "$SERVICE_NODE" != "$NODE_PATH" ]; then
        echo "⚠ Warning: Service file uses different Node.js path: $SERVICE_NODE"
        echo "Updating service file..."
        sed -i "s|ExecStart=.*node|ExecStart=$NODE_PATH|g" /etc/systemd/system/api-proxy.service
        systemctl daemon-reload
        echo "✓ Service file updated"
    fi
else
    echo "✗ Node.js not found"
    exit 1
fi
echo ""

echo "Step 5: Checking API proxy service logs..."
echo "Recent logs:"
journalctl -u api-proxy -n 30 --no-pager
echo ""

echo "Step 6: Testing if port 3001 is listening..."
if ss -tlnp 2>/dev/null | grep -q ":3001" || netstat -tlnp 2>/dev/null | grep -q ":3001"; then
    echo "✓ Port 3001 is listening"
    ss -tlnp 2>/dev/null | grep ":3001" || netstat -tlnp 2>/dev/null | grep ":3001"
else
    echo "✗ Port 3001 is NOT listening"
    echo "Service may not be running or failed to start"
fi
echo ""

echo "Step 7: Testing direct connection to API proxy..."
if curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://127.0.0.1:3001/api?type=log&log-type=traffic&nlogs=1 2>&1 | grep -qE "^[0-9]{3}$"; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://127.0.0.1:3001/api?type=log&log-type=traffic&nlogs=1)
    echo "✓ API proxy is responding (HTTP $HTTP_CODE)"
else
    echo "✗ API proxy is NOT responding"
    echo "Attempting to restart service..."
    systemctl restart api-proxy
    sleep 3
    if systemctl is-active --quiet api-proxy; then
        echo "✓ Service restarted successfully"
    else
        echo "✗ Service failed to start"
        echo "Check logs: journalctl -u api-proxy -n 50"
    fi
fi
echo ""

echo "Step 8: Checking SELinux (RHEL 9.7 specific)..."
if command -v getenforce &>/dev/null; then
    SELINUX_STATUS=$(getenforce)
    echo "SELinux status: $SELINUX_STATUS"
    
    if [ "$SELINUX_STATUS" != "Disabled" ]; then
        echo "Checking SELinux booleans..."
        getsebool httpd_can_network_connect 2>/dev/null || echo "  Boolean not found"
        
        echo "Checking for SELinux denials..."
        if command -v ausearch &>/dev/null; then
            RECENT_DENIALS=$(ausearch -m avc -ts recent 2>/dev/null | grep -i "nginx\|node\|3001" | head -5)
            if [ -n "$RECENT_DENIALS" ]; then
                echo "⚠ Recent SELinux denials found:"
                echo "$RECENT_DENIALS"
                echo ""
                echo "To fix SELinux issues, run:"
                echo "  setsebool -P httpd_can_network_connect 1"
                echo "  setsebool -P httpd_can_network_relay 1"
            else
                echo "✓ No recent SELinux denials"
            fi
        fi
    else
        echo "SELinux is disabled"
    fi
else
    echo "SELinux tools not available"
fi
echo ""

echo "Step 9: Checking Nginx configuration..."
if nginx -t 2>&1 | grep -q "successful"; then
    echo "✓ Nginx configuration is valid"
else
    echo "✗ Nginx configuration has errors:"
    nginx -t
fi
echo ""

echo "Step 10: Checking Nginx error logs for 502 errors..."
if [ -f /var/log/nginx/panovision-error.log ]; then
    echo "Recent 502-related errors:"
    grep -i "502\|bad gateway\|upstream\|connect() failed" /var/log/nginx/panovision-error.log | tail -10 || echo "No 502 errors in recent logs"
else
    echo "Error log not found"
fi
echo ""

echo "Step 11: Testing Nginx proxy..."
PROXY_TEST=$(curl -k -s -o /dev/null -w "%{http_code}" --max-time 10 "http://localhost/api/panorama?type=log&log-type=traffic&nlogs=1" 2>&1)
if [ "$PROXY_TEST" = "200" ] || [ "$PROXY_TEST" = "401" ] || [ "$PROXY_TEST" = "403" ]; then
    echo "✓ Nginx proxy is working (HTTP $PROXY_TEST)"
elif [ "$PROXY_TEST" = "502" ]; then
    echo "✗ Still getting 502 Bad Gateway"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Ensure API proxy service is running: systemctl status api-proxy"
    echo "2. Check service logs: journalctl -u api-proxy -f"
    echo "3. Verify port 3001: ss -tlnp | grep 3001"
    echo "4. Test direct connection: curl http://127.0.0.1:3001/api?type=log&log-type=traffic&nlogs=1"
    echo "5. Check SELinux: ausearch -m avc -ts recent"
else
    echo "⚠ Proxy returned HTTP $PROXY_TEST"
fi
echo ""

echo "=========================================="
echo "Fix Complete!"
echo "=========================================="
echo ""
echo "If 502 errors persist:"
echo "1. Restart services: systemctl restart api-proxy nginx"
echo "2. Check logs: journalctl -u api-proxy -n 50"
echo "3. Verify paths in service file match actual installation"
echo ""

