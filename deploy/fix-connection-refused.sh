#!/bin/bash

echo "=========================================="
echo "Fixing Connection Refused Error"
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

echo "Step 1: Checking if API proxy service is running..."
if systemctl is-active --quiet api-proxy; then
    echo "✓ Service is running"
    systemctl status api-proxy --no-pager -l | head -15
else
    echo "✗ Service is NOT running"
    echo "Checking why it failed..."
    systemctl status api-proxy --no-pager -l | head -20
fi
echo ""

echo "Step 2: Checking service logs for errors..."
echo "Recent logs:"
journalctl -u api-proxy -n 30 --no-pager --no-hostname
echo ""

echo "Step 3: Verifying service file configuration..."
if [ -f /etc/systemd/system/api-proxy.service ]; then
    echo "Service file:"
    cat /etc/systemd/system/api-proxy.service
    echo ""
    
    # Check if paths need updating
    if grep -q "/opt/panovision" /etc/systemd/system/api-proxy.service && [ "$PROJECT_DIR" != "/opt/panovision" ]; then
        echo "⚠ Fixing service file paths..."
        sed "s|/opt/panovision|$PROJECT_DIR|g" /etc/systemd/system/api-proxy.service > /tmp/api-proxy.service
        cp /tmp/api-proxy.service /etc/systemd/system/api-proxy.service
        rm -f /tmp/api-proxy.service
        systemctl daemon-reload
        echo "✓ Service file updated"
    fi
    
    # Check if Node.js path is correct
    NODE_PATH=$(which node)
    SERVICE_NODE=$(grep "^ExecStart=" /etc/systemd/system/api-proxy.service | cut -d'=' -f2 | cut -d' ' -f1)
    if [ "$SERVICE_NODE" != "$NODE_PATH" ] && [ -n "$NODE_PATH" ]; then
        echo "⚠ Fixing Node.js path..."
        sed -i "s|ExecStart=.*node|ExecStart=$NODE_PATH|g" /etc/systemd/system/api-proxy.service
        systemctl daemon-reload
        echo "✓ Node.js path updated to $NODE_PATH"
    fi
else
    echo "✗ Service file not found, creating it..."
    if [ -f "$PROJECT_DIR/deploy/api-proxy.service" ]; then
        sed "s|/opt/panovision|$PROJECT_DIR|g" "$PROJECT_DIR/deploy/api-proxy.service" > /etc/systemd/system/api-proxy.service
        NODE_PATH=$(which node)
        if [ -n "$NODE_PATH" ]; then
            sed -i "s|ExecStart=.*node|ExecStart=$NODE_PATH|g" /etc/systemd/system/api-proxy.service
        fi
        systemctl daemon-reload
        echo "✓ Service file created"
    else
        echo "✗ Cannot find service template file"
        exit 1
    fi
fi
echo ""

echo "Step 4: Checking API proxy file..."
if [ -f "$PROJECT_DIR/deploy/api-proxy.js" ]; then
    echo "✓ API proxy file exists"
    ls -l "$PROJECT_DIR/deploy/api-proxy.js"
    
    # Check if nginx user can read it
    if [ -r "$PROJECT_DIR/deploy/api-proxy.js" ]; then
        echo "✓ File is readable"
    else
        echo "⚠ Fixing file permissions..."
        chmod 755 "$PROJECT_DIR/deploy/api-proxy.js"
    fi
else
    echo "✗ API proxy file not found!"
    exit 1
fi
echo ""

echo "Step 5: Checking API key file..."
if [ -f /etc/panovision/api-key ]; then
    echo "✓ API key file exists"
    if [ -r /etc/panovision/api-key ]; then
        echo "✓ API key file is readable by nginx user"
    else
        echo "⚠ Fixing API key file permissions..."
        chmod 640 /etc/panovision/api-key
        chown root:nginx /etc/panovision/api-key
        echo "✓ Permissions fixed"
    fi
else
    echo "✗ API key file not found at /etc/panovision/api-key"
    echo "  This will cause the service to fail!"
fi
echo ""

echo "Step 6: Testing manual service start..."
echo "Attempting to start service..."
systemctl restart api-proxy
sleep 3

if systemctl is-active --quiet api-proxy; then
    echo "✓ Service started successfully"
else
    echo "✗ Service failed to start"
    echo ""
    echo "Checking recent logs for errors:"
    journalctl -u api-proxy -n 20 --no-pager --no-hostname
    echo ""
    echo "Trying to run service manually to see error:"
    echo "Running as nginx user:"
    sudo -u nginx node "$PROJECT_DIR/deploy/api-proxy.js" &
    MANUAL_PID=$!
    sleep 2
    if ps -p $MANUAL_PID > /dev/null; then
        echo "✓ Manual start succeeded (PID: $MANUAL_PID)"
        kill $MANUAL_PID 2>/dev/null
        echo "  This suggests a systemd configuration issue"
    else
        echo "✗ Manual start also failed"
        echo "  Check the error above - likely API key or config file issue"
    fi
fi
echo ""

echo "Step 7: Checking if port 3001 is listening..."
if ss -tlnp 2>/dev/null | grep -q ":3001" || netstat -tlnp 2>/dev/null | grep -q ":3001"; then
    echo "✓ Port 3001 is listening"
    ss -tlnp 2>/dev/null | grep ":3001" || netstat -tlnp 2>/dev/null | grep ":3001"
else
    echo "✗ Port 3001 is NOT listening"
    echo "  Service is not running or failed to bind to port"
fi
echo ""

echo "Step 8: Testing direct connection to API proxy..."
if curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://127.0.0.1:3001/api?type=log&log-type=traffic&nlogs=1 2>&1 | grep -qE "^[0-9]{3}$"; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://127.0.0.1:3001/api?type=log&log-type=traffic&nlogs=1)
    echo "✓ API proxy is responding (HTTP $HTTP_CODE)"
else
    echo "✗ Cannot connect to API proxy on port 3001"
    echo "  This confirms the connection refused error"
fi
echo ""

echo "Step 9: Checking SELinux (if enabled)..."
if command -v getenforce &>/dev/null; then
    if [ "$(getenforce)" != "Disabled" ]; then
        echo "SELinux is enabled, checking for denials..."
        if command -v ausearch &>/dev/null; then
            RECENT_DENIALS=$(ausearch -m avc -ts recent 2>/dev/null | grep -i "nginx\|node\|3001" | head -3)
            if [ -n "$RECENT_DENIALS" ]; then
                echo "⚠ SELinux denials found:"
                echo "$RECENT_DENIALS"
                echo ""
                echo "To fix SELinux issues:"
                echo "  setsebool -P httpd_can_network_connect 1"
                echo "  setsebool -P httpd_can_network_relay 1"
            fi
        fi
    fi
fi
echo ""

echo "=========================================="
echo "Diagnostic Complete"
echo "=========================================="
echo ""
echo "If service is still not working:"
echo "1. Check logs: journalctl -u api-proxy -f"
echo "2. Verify API key: cat /etc/panovision/api-key"
echo "3. Test manually: sudo -u nginx node $PROJECT_DIR/deploy/api-proxy.js"
echo "4. Check SELinux: ausearch -m avc -ts recent"
echo ""

