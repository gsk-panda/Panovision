#!/bin/bash

echo "=========================================="
echo "Fixing 502 Bad Gateway - Proxy Issues"
echo "=========================================="
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    exit 1
fi

echo "Step 1: Testing DNS resolution..."
if nslookup panorama.officeours.com >/dev/null 2>&1; then
    echo "✓ DNS resolution works"
    nslookup panorama.officeours.com | grep -A 2 "Name:"
else
    echo "✗ DNS resolution failed"
    echo "  Trying with dig..."
    dig panorama.officeours.com +short || echo "  Dig also failed"
fi
echo ""

echo "Step 2: Testing connectivity to Panorama..."
HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "https://panorama.officeours.com/api/?type=log&log-type=traffic&key=test&nlogs=1" 2>&1)
if echo "$HTTP_CODE" | grep -qE "^[0-9]{3}$"; then
    echo "✓ Can reach Panorama (HTTP $HTTP_CODE)"
else
    echo "✗ Cannot reach Panorama server"
    echo "  Testing basic connectivity..."
    ping -c 2 panorama.officeours.com 2>/dev/null && echo "  Ping works" || echo "  Ping failed"
    echo ""
    echo "  Testing port 443..."
    timeout 5 bash -c "</dev/tcp/panorama.officeours.com/443" 2>/dev/null && echo "  Port 443 is open" || echo "  Port 443 is not accessible"
fi
echo ""

echo "Step 3: Checking Nginx configuration..."
if nginx -t 2>&1 | grep -q "successful"; then
    echo "✓ Nginx configuration is valid"
else
    echo "✗ Nginx configuration has errors:"
    nginx -t
    exit 1
fi
echo ""

echo "Step 4: Updating Nginx configuration..."
cd /opt/panovision 2>/dev/null || cd $(dirname "$0")/..
if [ -f "deploy/nginx-panovision.conf" ]; then
    cp deploy/nginx-panovision.conf /etc/nginx/conf.d/panovision.conf
    echo "✓ Configuration file updated"
    
    if nginx -t 2>&1 | grep -q "successful"; then
        echo "✓ New configuration is valid"
        systemctl reload nginx
        echo "✓ Nginx reloaded"
    else
        echo "✗ New configuration has errors:"
        nginx -t
        exit 1
    fi
else
    echo "✗ Configuration file not found"
    exit 1
fi
echo ""

echo "Step 5: Testing proxy endpoint..."
sleep 2
echo "Testing with HTTPS (as browser would)..."
PROXY_TEST=$(curl -k -s -o /dev/null -w "%{http_code}" --max-time 10 "https://localhost/api/panorama?type=log&log-type=traffic&key=test&nlogs=1" 2>&1)
if [ "$PROXY_TEST" = "200" ] || [ "$PROXY_TEST" = "401" ] || [ "$PROXY_TEST" = "403" ]; then
    echo "✓ Proxy is working (HTTP $PROXY_TEST)"
elif [ "$PROXY_TEST" = "301" ] || [ "$PROXY_TEST" = "302" ]; then
    echo "⚠ Getting redirect (HTTP $PROXY_TEST)"
    echo "Following redirect to see final response..."
    FINAL_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" -L --max-time 10 "https://localhost/api/panorama?type=log&log-type=traffic&key=test&nlogs=1" 2>&1)
    echo "Final HTTP code after redirect: $FINAL_CODE"
    if [ "$FINAL_CODE" = "200" ] || [ "$FINAL_CODE" = "401" ] || [ "$FINAL_CODE" = "403" ]; then
        echo "✓ Proxy works after following redirect"
    fi
elif [ "$PROXY_TEST" = "502" ]; then
    echo "✗ Still getting 502 Bad Gateway"
    echo ""
    echo "Checking error logs..."
    tail -20 /var/log/nginx/panovision-error.log | grep -i "panorama\|502\|upstream" || tail -10 /var/log/nginx/panovision-error.log
    echo ""
    echo "Possible issues:"
    echo "1. Panorama server is not accessible from this server"
    echo "2. Firewall is blocking outbound HTTPS connections"
    echo "3. Panorama server is rejecting the connection"
    echo ""
    echo "Try manually: curl -k -v https://panorama.officeours.com/api/?type=log&log-type=traffic&key=TEST&nlogs=1"
else
    echo "Proxy test returned HTTP $PROXY_TEST"
fi
echo ""

echo "=========================================="
echo "Diagnostic Complete"
echo "=========================================="
echo ""

