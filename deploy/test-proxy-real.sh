#!/bin/bash

echo "=========================================="
echo "Testing Proxy with Real API Key"
echo "=========================================="
echo ""

API_KEY="LUFRPT0xQ0JKa2YrR1hFcVdra1pjL2Q2V2w0eXo0bmc9dzczNHg3T0VsRS9yYmFMcEpWdXBWdnF3cEQ2OTduSU9yRTlqQmJEbyt1bDY0NlR1VUhrNlkybGRRTHJ0Y2ZIdw=="

echo "1. Testing direct connection to Panorama..."
DIRECT_RESPONSE=$(curl -k -s "https://panorama.officeours.com/api/?type=log&log-type=traffic&key=${API_KEY}&nlogs=1")
if echo "$DIRECT_RESPONSE" | grep -q "<response"; then
    echo "✓ Direct connection works"
    echo "Response preview:"
    echo "$DIRECT_RESPONSE" | head -5
else
    echo "✗ Direct connection failed"
    echo "Response: $DIRECT_RESPONSE"
fi
echo ""

echo "2. Testing proxy endpoint..."
PROXY_RESPONSE=$(curl -k -s "https://panovision.officeours.com/api/panorama?type=log&log-type=traffic&key=${API_KEY}&nlogs=1")
if echo "$PROXY_RESPONSE" | grep -q "<response"; then
    echo "✓ Proxy is working!"
    echo "Response preview:"
    echo "$PROXY_RESPONSE" | head -5
elif echo "$PROXY_RESPONSE" | grep -q "502\|Bad Gateway"; then
    echo "✗ Proxy returned 502 Bad Gateway"
    echo "Full response:"
    echo "$PROXY_RESPONSE"
    echo ""
    echo "Checking Nginx error logs..."
    tail -10 /var/log/nginx/panovision-error.log
else
    echo "⚠ Unexpected response from proxy"
    echo "Response:"
    echo "$PROXY_RESPONSE" | head -20
fi
echo ""

echo "3. Testing proxy with verbose output..."
echo "Running: curl -k -v 'https://panovision.officeours.com/api/panorama?type=log&log-type=traffic&key=REDACTED&nlogs=1'"
curl -k -v "https://panovision.officeours.com/api/panorama?type=log&log-type=traffic&key=${API_KEY}&nlogs=1" 2>&1 | grep -E "(HTTP|Host|Location|502|error)" | head -10
echo ""

echo "=========================================="
echo "Test Complete"
echo "=========================================="

