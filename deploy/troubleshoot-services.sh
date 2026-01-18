#!/bin/bash

set -e

if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    exit 1
fi

PROJECT_DIR="/opt/Panovision"

echo "=========================================="
echo "PanoVision Service Troubleshooting"
echo "=========================================="
echo ""

echo "0. Checking for panovision.service (should not exist)..."
echo "-----------------------------------"
if [ -f "/etc/systemd/system/panovision.service" ]; then
    echo "✗ panovision.service file exists (should use api-proxy.service instead)"
    if grep -q "EnvironmentFile" /etc/systemd/system/panovision.service; then
        echo "  Service file references EnvironmentFile - this may be the issue"
        echo "  Run: sudo ./deploy/fix-panovision-service.sh"
    fi
else
    echo "✓ panovision.service does not exist (correct)"
fi

echo ""
echo "1. Checking API Proxy Service..."
echo "-----------------------------------"
if systemctl is-active --quiet api-proxy; then
    echo "✓ API proxy service is running"
else
    echo "✗ API proxy service is NOT running"
    echo ""
    echo "Checking file permissions..."
    if [ -f "$PROJECT_DIR/deploy/api-proxy.js" ]; then
        ls -la "$PROJECT_DIR/deploy/api-proxy.js"
        echo ""
        echo "Fixing permissions..."
        chown panovision:panovision "$PROJECT_DIR/deploy/api-proxy.js"
        chmod 755 "$PROJECT_DIR/deploy/api-proxy.js"
        chmod 755 "$PROJECT_DIR/deploy"
        
        if command -v getenforce &>/dev/null && [ "$(getenforce)" != "Disabled" ]; then
            chcon -t bin_t "$PROJECT_DIR/deploy/api-proxy.js" 2>/dev/null || true
        fi
        
        echo "Restarting service..."
        systemctl daemon-reload
        systemctl restart api-proxy
        sleep 2
        
        if systemctl is-active --quiet api-proxy; then
            echo "✓ API proxy service started successfully"
        else
            echo "✗ API proxy service still failing"
            echo "Recent logs:"
            journalctl -u api-proxy -n 20 --no-pager
        fi
    else
        echo "✗ API proxy file not found: $PROJECT_DIR/deploy/api-proxy.js"
    fi
fi

echo ""
echo "2. Checking Nginx Service..."
echo "-----------------------------------"
if systemctl is-active --quiet nginx; then
    echo "✓ Nginx service is running"
else
    echo "✗ Nginx service is NOT running"
    echo "Starting Nginx..."
    systemctl start nginx
    sleep 2
    if systemctl is-active --quiet nginx; then
        echo "✓ Nginx started successfully"
    else
        echo "✗ Nginx failed to start"
        echo "Recent logs:"
        journalctl -u nginx -n 20 --no-pager
        echo ""
        echo "Testing Nginx configuration:"
        nginx -t
    fi
fi

echo ""
echo "3. Checking Nginx Configuration..."
echo "-----------------------------------"
if nginx -t 2>&1 | grep -q "successful"; then
    echo "✓ Nginx configuration is valid"
else
    echo "✗ Nginx configuration has errors:"
    nginx -t
fi

echo ""
echo "4. Checking Listening Ports..."
echo "-----------------------------------"
if ss -tlnp | grep -q ":80 "; then
    echo "✓ Port 80 is listening"
    ss -tlnp | grep ":80 "
else
    echo "✗ Port 80 is NOT listening"
fi

if ss -tlnp | grep -q ":443 "; then
    echo "✓ Port 443 is listening"
    ss -tlnp | grep ":443 "
else
    echo "✗ Port 443 is NOT listening"
fi

if ss -tlnp | grep -q ":3001 "; then
    echo "✓ Port 3001 (API proxy) is listening"
    ss -tlnp | grep ":3001 "
else
    echo "✗ Port 3001 (API proxy) is NOT listening"
fi

echo ""
echo "5. Checking Firewall..."
echo "-----------------------------------"
if systemctl is-active --quiet firewalld; then
    echo "Firewalld is active"
    if firewall-cmd --list-all | grep -q "services:.*http"; then
        echo "✓ HTTP service is allowed"
    else
        echo "✗ HTTP service is NOT allowed"
        echo "Adding HTTP service..."
        firewall-cmd --permanent --add-service=http
        firewall-cmd --reload
    fi
    
    if firewall-cmd --list-all | grep -q "services:.*https"; then
        echo "✓ HTTPS service is allowed"
    else
        echo "✗ HTTPS service is NOT allowed"
        echo "Adding HTTPS service..."
        firewall-cmd --permanent --add-service=https
        firewall-cmd --reload
    fi
else
    echo "Firewalld is not active (check other firewall rules)"
fi

echo ""
echo "6. Checking SELinux..."
echo "-----------------------------------"
if command -v getenforce &>/dev/null; then
    SELINUX_STATUS=$(getenforce)
    echo "SELinux status: $SELINUX_STATUS"
    
    if [ "$SELINUX_STATUS" != "Disabled" ]; then
        if getsebool httpd_can_network_connect | grep -q "on$"; then
            echo "✓ Nginx network connections allowed"
        else
            echo "✗ Nginx network connections NOT allowed"
            echo "Setting SELinux boolean..."
            setsebool -P httpd_can_network_connect 1
        fi
        
        if [ -d "/var/www/panovision" ]; then
            CONTEXT=$(ls -Zd /var/www/panovision | awk '{print $4}' | cut -d: -f3)
            if [ "$CONTEXT" = "httpd_sys_content_t" ]; then
                echo "✓ Web directory has correct SELinux context"
            else
                echo "✗ Web directory has incorrect SELinux context: $CONTEXT"
                echo "Setting correct context..."
                chcon -R -t httpd_sys_content_t /var/www/panovision
            fi
        fi
    else
        echo "SELinux is disabled"
    fi
else
    echo "SELinux tools not found"
fi

echo ""
echo "7. Checking SSL Certificates..."
echo "-----------------------------------"
if [ -f "/etc/ssl/panovision/panovision-selfsigned.crt" ]; then
    echo "✓ SSL certificate exists"
    ls -la /etc/ssl/panovision/
else
    echo "✗ SSL certificate NOT found"
    echo "Creating self-signed certificate..."
    mkdir -p /etc/ssl/panovision
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/panovision/panovision-selfsigned.key \
        -out /etc/ssl/panovision/panovision-selfsigned.crt \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=panovision.example.com" 2>/dev/null
    chmod 600 /etc/ssl/panovision/panovision-selfsigned.key
    chmod 644 /etc/ssl/panovision/panovision-selfsigned.crt
    systemctl reload nginx
fi

echo ""
echo "8. Testing Local Connectivity..."
echo "-----------------------------------"
if curl -k -s -o /dev/null -w "%{http_code}" https://localhost >/dev/null 2>&1; then
    echo "✓ Nginx responds locally on HTTPS"
else
    echo "✗ Nginx does NOT respond locally on HTTPS"
fi

if curl -s -o /dev/null -w "%{http_code}" http://localhost >/dev/null 2>&1; then
    echo "✓ Nginx responds locally on HTTP"
else
    echo "✗ Nginx does NOT respond locally on HTTP"
fi

echo ""
echo "=========================================="
echo "Troubleshooting Complete"
echo "=========================================="
echo ""
echo "If issues persist, check:"
echo "  - Nginx logs: tail -f /var/log/nginx/panovision-error.log"
echo "  - API proxy logs: journalctl -u api-proxy -f"
echo "  - Nginx status: systemctl status nginx"
echo "  - API proxy status: systemctl status api-proxy"
