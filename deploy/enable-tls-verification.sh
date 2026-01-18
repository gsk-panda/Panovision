#!/bin/bash

if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    exit 1
fi

echo "=========================================="
echo "Re-enabling TLS Verification"
echo "=========================================="
echo ""

if [ ! -f "/etc/panovision/panorama-ca.crt" ]; then
    echo "⚠ Warning: Panorama CA certificate not found at /etc/panovision/panorama-ca.crt"
    echo ""
    echo "You need to install the Panorama CA certificate first:"
    echo "  sudo ./deploy/fetch-panorama-cert.sh"
    echo ""
    read -p "Continue anyway? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Aborted. Install the certificate first."
        exit 1
    fi
fi

echo "Removing systemd override..."
rm -rf /etc/systemd/system/api-proxy.service.d

echo "✓ Override removed"
echo ""
echo "Reloading systemd and restarting service..."
systemctl daemon-reload
systemctl restart api-proxy

sleep 2

if systemctl is-active --quiet api-proxy; then
    echo "✓ API proxy service restarted successfully"
    echo ""
    echo "TLS verification is now ENABLED"
    
    if [ -f "/etc/panovision/panorama-ca.crt" ]; then
        CERT_COUNT=$(grep -c "BEGIN CERTIFICATE" /etc/panovision/panorama-ca.crt || echo "0")
        echo "Using custom CA certificate ($CERT_COUNT certificate(s))"
    else
        echo "Using system CA store (if Panorama cert is in system store)"
    fi
else
    echo "⚠ Warning: API proxy service may have issues. Check logs:"
    echo "  journalctl -u api-proxy -n 20"
    echo ""
    echo "If you see certificate errors, install the Panorama CA certificate:"
    echo "  sudo ./deploy/fetch-panorama-cert.sh"
fi

