#!/bin/bash

set -e

# Generate CSR for Apache SSL Certificate on RHEL
# This creates a Certificate Signing Request for a proper SSL certificate

if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    exit 1
fi

SSL_DIR="/etc/ssl/panovision"
KEY_FILE="$SSL_DIR/panovision.key"
CSR_FILE="$SSL_DIR/panovision.csr"

echo "=========================================="
echo "Generate Apache SSL Certificate CSR"
echo "=========================================="
echo ""

# Create SSL directory if it doesn't exist
mkdir -p "$SSL_DIR"

# Get server information
read -p "Common Name (CN) - Domain name or IP [e.g., panovision.sncorp.com or 10.100.5.227]: " CN
if [ -z "$CN" ]; then
    echo "Error: Common Name is required"
    exit 1
fi

read -p "Organization (O) [e.g., Your Company Name]: " ORG
ORG=${ORG:-"Organization"}

read -p "Organizational Unit (OU) [e.g., IT Department]: " OU
OU=${OU:-"IT"}

read -p "City/Locality (L) [e.g., City]: " CITY
CITY=${CITY:-"City"}

read -p "State/Province (ST) [e.g., State]: " STATE
STATE=${STATE:-"State"}

read -p "Country Code (C) [2-letter code, e.g., US]: " COUNTRY
COUNTRY=${COUNTRY:-"US"}

read -p "Email Address (optional): " EMAIL

echo ""
echo "Key size (2048 or 4096 bits):"
read -p "Choose key size [2048/4096, default: 2048]: " KEY_SIZE
KEY_SIZE=${KEY_SIZE:-2048}

if [ "$KEY_SIZE" != "2048" ] && [ "$KEY_SIZE" != "4096" ]; then
    echo "Invalid key size, using 2048"
    KEY_SIZE=2048
fi

echo ""
echo "=========================================="
echo "Generating Private Key and CSR"
echo "=========================================="
echo ""

# Backup existing key if it exists
if [ -f "$KEY_FILE" ]; then
    BACKUP_KEY="${KEY_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    echo "Backing up existing private key to: $BACKUP_KEY"
    cp "$KEY_FILE" "$BACKUP_KEY"
    chmod 600 "$BACKUP_KEY"
fi

# Generate private key
echo "1. Generating private key ($KEY_SIZE bits)..."
openssl genrsa -out "$KEY_FILE" "$KEY_SIZE" 2>/dev/null
chmod 600 "$KEY_FILE"
echo "✓ Private key generated: $KEY_FILE"

# Build subject string
SUBJECT="/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORG/OU=$OU/CN=$CN"

if [ -n "$EMAIL" ]; then
    SUBJECT="$SUBJECT/emailAddress=$EMAIL"
fi

# Generate CSR
echo ""
echo "2. Generating Certificate Signing Request..."
openssl req -new -key "$KEY_FILE" -out "$CSR_FILE" -subj "$SUBJECT" 2>/dev/null
chmod 644 "$CSR_FILE"
echo "✓ CSR generated: $CSR_FILE"

# Display CSR information
echo ""
echo "=========================================="
echo "CSR Information"
echo "=========================================="
echo ""
echo "Subject: $SUBJECT"
echo ""
echo "Private Key: $KEY_FILE"
echo "CSR File: $CSR_FILE"
echo ""

# Display CSR contents
echo "CSR Contents:"
echo "----------------------------------------"
cat "$CSR_FILE"
echo "----------------------------------------"
echo ""

# Verify CSR
echo "3. Verifying CSR..."
if openssl req -in "$CSR_FILE" -noout -text >/dev/null 2>&1; then
    echo "✓ CSR is valid"
    echo ""
    echo "CSR Details:"
    openssl req -in "$CSR_FILE" -noout -text | grep -E "Subject:|Public Key Algorithm:|Signature Algorithm:" | head -5
else
    echo "✗ CSR verification failed"
    exit 1
fi

echo ""
echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo ""
echo "1. Copy the CSR file to your Certificate Authority (CA):"
echo "   cat $CSR_FILE"
echo ""
echo "   Or copy the file:"
echo "   scp $CSR_FILE user@ca-server:/path/to/"
echo ""
echo "2. Submit the CSR to your CA (internal CA, Let's Encrypt, commercial CA, etc.)"
echo ""
echo "3. Once you receive the certificate, save it to:"
echo "   /etc/ssl/panovision/panovision.crt"
echo ""
echo "4. If you receive intermediate certificates, save them to:"
echo "   /etc/ssl/panovision/panovision-chain.crt"
echo ""
echo "5. Update Apache configuration to use the new certificate:"
echo "   SSLCertificateFile /etc/ssl/panovision/panovision.crt"
echo "   SSLCertificateKeyFile $KEY_FILE"
echo "   SSLCertificateChainFile /etc/ssl/panovision/panovision-chain.crt  # if applicable"
echo ""
echo "6. Restart Apache:"
echo "   systemctl restart httpd"
echo ""
echo "=========================================="
echo "Security Notes"
echo "=========================================="
echo ""
echo "⚠ IMPORTANT: Keep your private key secure!"
echo "   - The private key ($KEY_FILE) should NEVER be shared"
echo "   - Only the CSR file should be sent to the CA"
echo "   - File permissions: $KEY_FILE (600 - root only)"
echo ""
echo "To view CSR details later:"
echo "   openssl req -in $CSR_FILE -noout -text"
echo ""
echo "To view private key details (do not share):"
echo "   openssl rsa -in $KEY_FILE -noout -text"
echo ""
