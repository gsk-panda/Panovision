#!/bin/bash

echo "=========================================="
echo "Fixing API Proxy Service"
echo "=========================================="
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    exit 1
fi

echo "Step 1: Checking API proxy service status..."
if systemctl is-active --quiet api-proxy; then
    echo "✓ API proxy service is running"
else
    echo "✗ API proxy service is not running"
    echo "Checking service status..."
    systemctl status api-proxy --no-pager -l
fi
echo ""

echo "Step 2: Checking API key file permissions..."
if [ -f /etc/panovision/api-key ]; then
    echo "✓ API key file exists"
    ls -l /etc/panovision/api-key
    if [ -r /etc/panovision/api-key ]; then
        echo "✓ API key file is readable"
    else
        echo "✗ API key file is not readable by current user"
        echo "Fixing permissions..."
        chmod 640 /etc/panovision/api-key
        chown root:nginx /etc/panovision/api-key
        echo "✓ Permissions fixed"
    fi
else
    echo "✗ API key file not found at /etc/panovision/api-key"
    echo "Please run the install script to create it"
    exit 1
fi
echo ""

echo "Step 3: Checking Panorama config file..."
if [ -f /etc/panovision/panorama-config ]; then
    echo "✓ Panorama config file exists"
    cat /etc/panovision/panorama-config
else
    echo "✗ Panorama config file not found"
fi
echo ""

echo "Step 4: Checking API proxy service logs..."
echo "Recent logs:"
journalctl -u api-proxy -n 20 --no-pager
echo ""

echo "Step 5: Testing API proxy service..."
if systemctl is-active --quiet api-proxy; then
    TEST_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3001/api/panorama?type=log&log-type=traffic&nlogs=1 2>&1)
    if [ "$TEST_RESPONSE" = "200" ] || [ "$TEST_RESPONSE" = "401" ] || [ "$TEST_RESPONSE" = "403" ]; then
        echo "✓ API proxy is responding (HTTP $TEST_RESPONSE)"
    else
        echo "✗ API proxy returned HTTP $TEST_RESPONSE"
    fi
else
    echo "Restarting API proxy service..."
    systemctl restart api-proxy
    sleep 2
    if systemctl is-active --quiet api-proxy; then
        echo "✓ API proxy service started"
    else
        echo "✗ Failed to start API proxy service"
        echo "Check logs: journalctl -u api-proxy -n 50"
    fi
fi
echo ""

echo "Step 6: Checking if port 3001 is listening..."
if netstat -tlnp 2>/dev/null | grep -q ":3001" || ss -tlnp 2>/dev/null | grep -q ":3001"; then
    echo "✓ Port 3001 is listening"
    netstat -tlnp 2>/dev/null | grep ":3001" || ss -tlnp 2>/dev/null | grep ":3001"
else
    echo "✗ Port 3001 is not listening"
fi
echo ""

echo "=========================================="
echo "Fix Complete!"
echo "=========================================="
echo ""
echo "If issues persist, check:"
echo "  - Service logs: journalctl -u api-proxy -f"
echo "  - Nginx error logs: tail -f /var/log/nginx/panovision-error.log"
echo "  - Test proxy: curl http://127.0.0.1:3001/api/panorama?type=log&log-type=traffic&nlogs=1"
echo ""

