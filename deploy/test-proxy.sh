#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
else
    PANORAMA_URL="${PANORAMA_URL:-https://panorama.example.com}"
fi

PANORAMA_HOST=$(echo "$PANORAMA_URL" | sed 's|https\?://||' | sed 's|/.*||')

echo "=========================================="
echo "Testing Panorama Proxy Connection"
echo "=========================================="
echo ""

echo "1. Testing direct connection to Panorama..."
if curl -k -s -o /dev/null -w "%{http_code}" "$PANORAMA_URL/api/?type=log&log-type=traffic&key=test&nlogs=1" | grep -q "200\|401\|403"; then
    echo "✓ Can reach Panorama server"
else
    echo "✗ Cannot reach Panorama server"
    echo "  Testing DNS resolution..."
    nslookup "$PANORAMA_HOST"
    echo ""
    echo "  Testing connectivity..."
    ping -c 2 "$PANORAMA_HOST" 2>/dev/null || echo "  Ping failed"
fi
echo ""

echo "2. Checking Nginx proxy configuration..."
if nginx -t 2>&1 | grep -q "successful"; then
    echo "✓ Nginx configuration is valid"
else
    echo "✗ Nginx configuration has errors:"
    nginx -t
fi
echo ""

echo "3. Testing proxy endpoint locally..."
PROXY_TEST=$(curl -k -s -o /dev/null -w "%{http_code}" http://localhost/api/panorama?type=log&log-type=traffic&key=test&nlogs=1 2>&1)
if [ "$PROXY_TEST" = "200" ] || [ "$PROXY_TEST" = "401" ] || [ "$PROXY_TEST" = "403" ] || [ "$PROXY_TEST" = "502" ]; then
    echo "Proxy responded with HTTP $PROXY_TEST"
    if [ "$PROXY_TEST" = "502" ]; then
        echo "✗ 502 Bad Gateway - Check Nginx error logs"
        echo "  Run: tail -20 /var/log/nginx/panovision-error.log"
    else
        echo "✓ Proxy is working"
    fi
else
    echo "✗ Proxy test failed: HTTP $PROXY_TEST"
fi
echo ""

echo "4. Checking Nginx error logs (last 10 lines)..."
tail -10 /var/log/nginx/panovision-error.log 2>/dev/null || echo "No error log found"
echo ""

echo "5. Checking if required Nginx modules are loaded..."
nginx -V 2>&1 | grep -o "with-http_ssl_module\|with-http_proxy_module" || echo "Checking modules..."
echo ""

echo "=========================================="
echo "Troubleshooting Tips:"
echo "=========================================="
echo ""
echo "If you see 502 errors:"
echo "1. Verify Panorama server is accessible: curl -k $PANORAMA_URL"
echo "2. Check Nginx can resolve DNS: nslookup $PANORAMA_HOST"
echo "3. Review error logs: tail -f /var/log/nginx/panovision-error.log"
echo "4. Test proxy directly: curl -k 'http://localhost/api/panorama?type=log&log-type=traffic&key=TEST&nlogs=1'"
echo ""

