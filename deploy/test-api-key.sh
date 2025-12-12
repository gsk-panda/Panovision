#!/bin/bash

echo "=========================================="
echo "Testing API Key Configuration"
echo "=========================================="
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    exit 1
fi

API_KEY_FILE="/etc/panovision/api-key"
PANORAMA_CONFIG="/etc/panovision/panorama-config"

echo "Step 1: Checking API key file..."
if [ -f "$API_KEY_FILE" ]; then
    echo "✓ API key file exists"
    ls -l "$API_KEY_FILE"
    echo ""
    echo "API key file size: $(wc -c < "$API_KEY_FILE" | tr -d ' ') bytes"
    echo "API key file content (first 20 chars): $(head -c 20 "$API_KEY_FILE")..."
    echo "API key file content (last 20 chars): ...$(tail -c 20 "$API_KEY_FILE")"
    echo ""
    
    # Check for hidden characters
    echo "Checking for hidden characters..."
    HEX_DUMP=$(xxd -l 100 "$API_KEY_FILE" 2>/dev/null || od -An -tx1 "$API_KEY_FILE" | head -5)
    if [ -n "$HEX_DUMP" ]; then
        echo "First 100 bytes (hex):"
        echo "$HEX_DUMP"
    fi
    echo ""
    
    # Check for newlines
    if grep -q $'\r' "$API_KEY_FILE" || grep -q $'\n' "$API_KEY_FILE"; then
        echo "⚠ Warning: API key contains newline or carriage return characters"
        echo "  This may cause authentication issues"
    else
        echo "✓ No newline characters found"
    fi
else
    echo "✗ API key file not found"
    exit 1
fi
echo ""

echo "Step 2: Testing API key from file..."
STORED_KEY=$(cat "$API_KEY_FILE" | tr -d '\r\n' | tr -d '\n')
if [ -z "$STORED_KEY" ]; then
    echo "✗ API key is empty"
    exit 1
fi
echo "✓ API key loaded from file (${#STORED_KEY} characters)"
echo ""

echo "Step 3: Getting Panorama URL..."
if [ -f "$PANORAMA_CONFIG" ]; then
    PANORAMA_URL=$(grep "^PANORAMA_URL=" "$PANORAMA_CONFIG" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    echo "✓ Panorama URL: $PANORAMA_URL"
else
    echo "✗ Panorama config not found"
    read -p "Enter Panorama URL: " PANORAMA_URL
fi
echo ""

echo "Step 4: Testing direct connection with stored API key..."
TEST_URL="${PANORAMA_URL}/api/?type=log&log-type=traffic&key=${STORED_KEY}&nlogs=1"
echo "Testing: ${PANORAMA_URL}/api/?type=log&log-type=traffic&key=***&nlogs=1"
HTTP_CODE=$(curl -k -s -o /tmp/panorama-test-response.xml -w "%{http_code}" --max-time 10 "$TEST_URL" 2>&1)
echo "HTTP Response Code: $HTTP_CODE"

if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Direct connection successful!"
    echo "Response preview:"
    head -5 /tmp/panorama-test-response.xml
elif [ "$HTTP_CODE" = "403" ]; then
    echo "✗ 403 Forbidden - Authentication failed"
    echo "Response:"
    cat /tmp/panorama-test-response.xml
    echo ""
    echo "Possible issues:"
    echo "  - API key may be incorrect or expired"
    echo "  - API key may have been corrupted during storage"
    echo "  - Check if API key has special characters that need encoding"
elif [ "$HTTP_CODE" = "401" ]; then
    echo "✗ 401 Unauthorized - Authentication failed"
    echo "Response:"
    cat /tmp/panorama-test-response.xml
else
    echo "⚠ Unexpected response: HTTP $HTTP_CODE"
    echo "Response:"
    head -20 /tmp/panorama-test-response.xml
fi
echo ""

echo "Step 5: Testing through API proxy service..."
if systemctl is-active --quiet api-proxy; then
    PROXY_TEST=$(curl -s -o /tmp/proxy-test-response.xml -w "%{http_code}" "http://127.0.0.1:3001/api?type=log&log-type=traffic&nlogs=1" 2>&1)
    echo "Proxy HTTP Response Code: $PROXY_TEST"
    if [ "$PROXY_TEST" = "200" ]; then
        echo "✓ Proxy connection successful!"
    elif [ "$PROXY_TEST" = "403" ] || [ "$PROXY_TEST" = "401" ]; then
        echo "✗ Proxy authentication failed (HTTP $PROXY_TEST)"
        echo "Response:"
        head -20 /tmp/proxy-test-response.xml
        echo ""
        echo "Check API proxy service logs:"
        echo "  journalctl -u api-proxy -n 20"
    else
        echo "⚠ Proxy returned HTTP $PROXY_TEST"
        echo "Response:"
        head -20 /tmp/proxy-test-response.xml
    fi
else
    echo "✗ API proxy service is not running"
fi
echo ""

echo "Step 6: Comparing API key formats..."
echo "If you have a working API key from your PC, compare:"
echo "  - Length: Should match"
echo "  - Characters: Should be identical"
echo "  - No extra whitespace or newlines"
echo ""
echo "To manually update the API key:"
echo "  printf '%s' 'YOUR_API_KEY' > /etc/panovision/api-key"
echo "  chmod 640 /etc/panovision/api-key"
echo "  chown root:nginx /etc/panovision/api-key"
echo "  systemctl restart api-proxy"
echo ""

rm -f /tmp/panorama-test-response.xml /tmp/proxy-test-response.xml

