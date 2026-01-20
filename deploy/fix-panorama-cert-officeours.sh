#!/bin/bash

# Quick fix script to install Panorama CA certificate for officeours.com

if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    exit 1
fi

PANORAMA_HOST="panorama.officeours.com"
CA_FILE="/etc/panovision/panorama-ca.crt"

echo "=========================================="
echo "Installing Panorama CA Certificate"
echo "=========================================="
echo ""
echo "Panorama: $PANORAMA_HOST"
echo ""

mkdir -p /etc/panovision

echo "Step 1: Extracting certificate chain from $PANORAMA_HOST..."
if ! command -v openssl &>/dev/null; then
    echo "Error: openssl is not installed"
    echo "Install it with: dnf install openssl"
    exit 1
fi

echo "Connecting to: ${PANORAMA_HOST}:443"

# Extract full certificate chain including server and intermediate certificates
echo | openssl s_client -showcerts -connect "${PANORAMA_HOST}:443" -servername "${PANORAMA_HOST}" 2>&1 | \
    sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > "$CA_FILE"

if [ ! -s "$CA_FILE" ]; then
    echo "⚠ Warning: Could not extract certificate chain. Trying alternative method..."
    echo | openssl s_client -connect "${PANORAMA_HOST}:443" -servername "${PANORAMA_HOST}" 2>&1 | \
        sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > "$CA_FILE"
fi

# Try to get the complete chain by following certificate links
if [ -s "$CA_FILE" ]; then
    echo "Attempting to extract complete certificate chain..."
    TEMP_CHAIN=$(mktemp)
    echo | openssl s_client -showcerts -verify_return_error -connect "${PANORAMA_HOST}:443" -servername "${PANORAMA_HOST}" 2>&1 | \
        sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > "$TEMP_CHAIN"
    
    if [ -s "$TEMP_CHAIN" ]; then
        # Combine both extractions to ensure we have all certificates
        cat "$TEMP_CHAIN" >> "$CA_FILE"
        # Remove duplicates by sorting and using unique
        sort -u "$CA_FILE" > "${CA_FILE}.tmp" && mv "${CA_FILE}.tmp" "$CA_FILE"
        rm -f "$TEMP_CHAIN"
    fi
fi

if [ -s "$CA_FILE" ]; then
    CERT_COUNT=$(grep -c "BEGIN CERTIFICATE" "$CA_FILE" || echo "0")
    echo "✓ Successfully extracted $CERT_COUNT certificate(s)"
    
    chmod 644 "$CA_FILE"
    chown root:panovision "$CA_FILE"
    
    echo ""
    echo "Certificate saved to: $CA_FILE"
    echo ""
    echo "Step 2: Restarting API proxy service..."
    systemctl restart api-proxy
    
    sleep 2
    
    if systemctl is-active --quiet api-proxy; then
        echo "✓ API proxy service restarted successfully"
        echo ""
        echo "=========================================="
        echo "Certificate Installation Complete!"
        echo "=========================================="
        echo ""
        echo "The API proxy should now be able to verify Panorama's SSL certificate."
        echo "Try accessing the application again."
    else
        echo "⚠ Warning: API proxy service may have issues. Check logs:"
        echo "  journalctl -u api-proxy -n 20"
    fi
else
    echo "✗ Failed to extract certificate"
    echo ""
    echo "Possible issues:"
    echo "  1. Cannot connect to $PANORAMA_HOST:443"
    echo "  2. Firewall blocking connection"
    echo "  3. Panorama server not responding"
    echo ""
    echo "Test connectivity:"
    echo "  openssl s_client -connect ${PANORAMA_HOST}:443 -servername ${PANORAMA_HOST}"
    echo ""
    echo "Alternative: Download the CA certificate manually from your Panorama server"
    echo "and save it to: $CA_FILE"
    exit 1
fi
