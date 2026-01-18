#!/bin/bash

if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    exit 1
fi

echo "=========================================="
echo "Disabling TLS Verification (Testing Only)"
echo "=========================================="
echo ""
echo "WARNING: This disables TLS certificate verification."
echo "This is INSECURE and should only be used for testing!"
echo ""

read -p "Are you sure you want to continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Creating systemd override..."
mkdir -p /etc/systemd/system/api-proxy.service.d

cat > /etc/systemd/system/api-proxy.service.d/override.conf <<EOF
[Service]
Environment="PANORAMA_VERIFY_SSL=false"
EOF

echo "✓ Override file created"
echo ""
echo "Reloading systemd and restarting service..."
systemctl daemon-reload
systemctl restart api-proxy

sleep 2

if systemctl is-active --quiet api-proxy; then
    echo "✓ API proxy service restarted successfully"
    echo ""
    echo "TLS verification is now DISABLED (insecure - testing only)"
    echo ""
    echo "To re-enable TLS verification later:"
    echo "  1. Install Panorama CA certificate: sudo ./deploy/fetch-panorama-cert.sh"
    echo "  2. Remove override: sudo rm -rf /etc/systemd/system/api-proxy.service.d"
    echo "  3. Restart: sudo systemctl daemon-reload && sudo systemctl restart api-proxy"
else
    echo "⚠ Warning: API proxy service may have issues. Check logs:"
    echo "  journalctl -u api-proxy -n 20"
fi

