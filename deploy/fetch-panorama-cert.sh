#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
fi

if [ -f "/etc/panovision/panorama-config" ]; then
    PANORAMA_URL=$(grep "^PANORAMA_URL=" /etc/panovision/panorama-config | cut -d'=' -f2- | tr -d '"' | tr -d "'")
fi

PANORAMA_URL="${PANORAMA_URL:-https://panorama.example.com}"

CA_FILE="/etc/panovision/panorama-ca.crt"

if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    exit 1
fi

echo "=========================================="
echo "Fetching Panorama CA Certificate"
echo "=========================================="
echo ""
echo "Panorama URL: $PANORAMA_URL"
echo ""

mkdir -p /etc/panovision

echo "Step 1: Extracting certificate chain from Panorama server..."
if command -v openssl &>/dev/null; then
    PANORAMA_HOST=$(echo $PANORAMA_URL | sed 's|https\?://||' | cut -d'/' -f1)
    echo "Connecting to: ${PANORAMA_HOST}:443"
    
    echo | openssl s_client -showcerts -connect "${PANORAMA_HOST}:443" -servername "${PANORAMA_HOST}" 2>&1 | \
        sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > "$CA_FILE"
    
    if [ ! -s "$CA_FILE" ]; then
        echo "⚠ Warning: Could not extract certificate chain. Trying alternative method..."
        echo | openssl s_client -connect "${PANORAMA_HOST}:443" -servername "${PANORAMA_HOST}" 2>&1 | \
            sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > "$CA_FILE"
    fi
    
    if [ -s "$CA_FILE" ]; then
        echo "✓ Certificate data extracted"
    else
        echo "✗ Failed to extract certificate. Check connectivity to ${PANORAMA_HOST}:443"
        exit 1
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
        
        if systemctl is-active --quiet api-proxy; then
            echo "✓ API proxy service restarted successfully"
        else
            echo "⚠ Warning: API proxy service may have issues. Check logs: journalctl -u api-proxy"
        fi
        
        echo ""
        echo "=========================================="
        echo "Certificate Installation Complete!"
        echo "=========================================="
    else
        echo "✗ Failed to extract certificate"
        echo ""
        echo "Alternative: Download the CA certificate manually from your Panorama server"
        echo "and save it to: $CA_FILE"
        exit 1
    fi
else
    echo "Error: openssl is not installed"
    echo "Install it with: dnf install openssl"
    exit 1
fi

