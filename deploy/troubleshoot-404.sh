#!/bin/bash

echo "=========================================="
echo "PanoVision 404 Troubleshooting Script"
echo "=========================================="
echo ""

echo "1. Checking Nginx status..."
systemctl status nginx --no-pager -l | head -10
echo ""

echo "2. Checking if application files exist..."
if [ -f "/var/www/panovision/index.html" ]; then
    echo "✓ index.html found at /var/www/panovision/index.html"
    ls -lh /var/www/panovision/index.html
else
    echo "✗ index.html NOT found at /var/www/panovision/index.html"
fi
echo ""

echo "3. Listing files in /var/www/panovision..."
ls -la /var/www/panovision/ | head -20
echo ""

echo "4. Checking Nginx configuration..."
if [ -f "/etc/nginx/conf.d/panovision.conf" ]; then
    echo "✓ Nginx config found"
    echo "Root directory setting:"
    grep "root" /etc/nginx/conf.d/panovision.conf | head -1
else
    echo "✗ Nginx config not found at /etc/nginx/conf.d/panovision.conf"
fi
echo ""

echo "5. Testing Nginx configuration..."
nginx -t
echo ""

echo "6. Checking Nginx error logs (last 20 lines)..."
if [ -f "/var/log/nginx/panovision-error.log" ]; then
    tail -20 /var/log/nginx/panovision-error.log
else
    echo "Error log not found, checking general Nginx error log..."
    tail -20 /var/log/nginx/error.log 2>/dev/null || echo "No error log found"
fi
echo ""

echo "7. Checking Nginx access logs (last 10 lines)..."
if [ -f "/var/log/nginx/panovision-access.log" ]; then
    tail -10 /var/log/nginx/panovision-access.log
else
    echo "Access log not found"
fi
echo ""

echo "8. Checking file permissions..."
ls -ld /var/www/panovision
ls -ld /var/www/panovision/index.html 2>/dev/null || echo "index.html not found"
echo ""

echo "=========================================="
echo "Quick Fix Commands:"
echo "=========================================="
echo ""
echo "If files are in wrong location, fix Nginx config:"
echo "  sed -i 's|root /var/www/panovision/dist;|root /var/www/panovision;|g' /etc/nginx/conf.d/panovision.conf"
echo ""
echo "Then reload Nginx:"
echo "  nginx -t && systemctl reload nginx"
echo ""

