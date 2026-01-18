#!/bin/bash

set -e

# Install SSL Certificate and Private Key for Apache

if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    exit 1
fi

SSL_DIR="/etc/ssl/panovision"
APACHE_CONF="/etc/httpd/conf.d/panovision.conf"

echo "=========================================="
echo "Install Apache SSL Certificate"
echo "=========================================="
echo ""

# Create SSL directory if it doesn't exist
mkdir -p "$SSL_DIR"

echo "This script will help you install your SSL certificate and private key for Apache."
echo ""
echo "You need:"
echo "  1. Your SSL certificate file (.crt or .pem)"
echo "  2. Your private key file (.key)"
echo ""

# Get certificate file
read -p "Path to your SSL certificate file (.crt or .pem): " CERT_FILE
if [ -z "$CERT_FILE" ]; then
    echo "Error: Certificate file path is required"
    exit 1
fi

if [ ! -f "$CERT_FILE" ]; then
    echo "Error: Certificate file not found: $CERT_FILE"
    exit 1
fi

# Get private key file
read -p "Path to your private key file (.key): " KEY_FILE
if [ -z "$KEY_FILE" ]; then
    echo "Error: Private key file path is required"
    exit 1
fi

if [ ! -f "$KEY_FILE" ]; then
    echo "Error: Private key file not found: $KEY_FILE"
    exit 1
fi

# Ask about intermediate/chain certificate
read -p "Do you have an intermediate/chain certificate file? (y/n): " HAS_CHAIN
HAS_CHAIN=${HAS_CHAIN:-n}

CHAIN_FILE=""
if [ "$HAS_CHAIN" = "y" ] || [ "$HAS_CHAIN" = "Y" ]; then
    read -p "Path to your intermediate/chain certificate file: " CHAIN_FILE
    if [ -n "$CHAIN_FILE" ] && [ ! -f "$CHAIN_FILE" ]; then
        echo "Warning: Chain certificate file not found: $CHAIN_FILE"
        read -p "Continue without chain certificate? (y/n): " CONTINUE
        if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
            exit 1
        fi
        CHAIN_FILE=""
    fi
fi

echo ""
echo "=========================================="
echo "Installing SSL Certificate"
echo "=========================================="
echo ""

# Backup existing certificates
if [ -f "$SSL_DIR/panovision.crt" ]; then
    BACKUP_CRT="${SSL_DIR}/panovision.crt.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$SSL_DIR/panovision.crt" "$BACKUP_CRT"
    echo "✓ Backed up existing certificate to: $BACKUP_CRT"
fi

if [ -f "$SSL_DIR/panovision.key" ]; then
    BACKUP_KEY="${SSL_DIR}/panovision.key.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$SSL_DIR/panovision.key" "$BACKUP_KEY"
    echo "✓ Backed up existing private key to: $BACKUP_KEY"
fi

# Copy certificate
echo "1. Copying SSL certificate..."
cp "$CERT_FILE" "$SSL_DIR/panovision.crt"
chmod 644 "$SSL_DIR/panovision.crt"
chown root:root "$SSL_DIR/panovision.crt"
echo "✓ Certificate installed: $SSL_DIR/panovision.crt"

# Copy private key
echo ""
echo "2. Copying private key..."
cp "$KEY_FILE" "$SSL_DIR/panovision.key"
chmod 600 "$SSL_DIR/panovision.key"
chown root:root "$SSL_DIR/panovision.key"
echo "✓ Private key installed: $SSL_DIR/panovision.key"

# Copy chain certificate if provided
if [ -n "$CHAIN_FILE" ] && [ -f "$CHAIN_FILE" ]; then
    echo ""
    echo "3. Copying intermediate/chain certificate..."
    cp "$CHAIN_FILE" "$SSL_DIR/panovision-chain.crt"
    chmod 644 "$SSL_DIR/panovision-chain.crt"
    chown root:root "$SSL_DIR/panovision-chain.crt"
    echo "✓ Chain certificate installed: $SSL_DIR/panovision-chain.crt"
fi

# Verify certificate
echo ""
echo "4. Verifying certificate..."
if openssl x509 -in "$SSL_DIR/panovision.crt" -noout -text >/dev/null 2>&1; then
    echo "✓ Certificate is valid"
    echo ""
    echo "Certificate details:"
    openssl x509 -in "$SSL_DIR/panovision.crt" -noout -subject -issuer -dates
else
    echo "✗ Certificate verification failed"
    exit 1
fi

# Verify private key
echo ""
echo "5. Verifying private key..."
if openssl rsa -in "$SSL_DIR/panovision.key" -noout -check >/dev/null 2>&1; then
    echo "✓ Private key is valid"
else
    echo "✗ Private key verification failed"
    exit 1
fi

# Verify certificate and key match
echo ""
echo "6. Verifying certificate and key match..."
CERT_MODULUS=$(openssl x509 -noout -modulus -in "$SSL_DIR/panovision.crt" | openssl md5)
KEY_MODULUS=$(openssl rsa -noout -modulus -in "$SSL_DIR/panovision.key" | openssl md5)

if [ "$CERT_MODULUS" = "$KEY_MODULUS" ]; then
    echo "✓ Certificate and private key match"
else
    echo "✗ Certificate and private key do NOT match!"
    echo "  This certificate/key pair will not work together"
    exit 1
fi

# Update Apache configuration
echo ""
echo "7. Updating Apache configuration..."

if [ ! -f "$APACHE_CONF" ]; then
    echo "Error: Apache configuration file not found: $APACHE_CONF"
    echo "Please run the installation script first"
    exit 1
fi

# Backup Apache config
BACKUP_CONF="${APACHE_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$APACHE_CONF" "$BACKUP_CONF"
echo "✓ Backed up Apache configuration to: $BACKUP_CONF"

# Update certificate paths in Apache config
sed -i 's|SSLCertificateFile.*|SSLCertificateFile /etc/ssl/panovision/panovision.crt|' "$APACHE_CONF"
sed -i 's|SSLCertificateKeyFile.*|SSLCertificateKeyFile /etc/ssl/panovision/panovision.key|' "$APACHE_CONF"

# Add chain certificate if provided
if [ -n "$CHAIN_FILE" ] && [ -f "$SSL_DIR/panovision-chain.crt" ]; then
    if grep -q "SSLCertificateChainFile" "$APACHE_CONF"; then
        sed -i 's|SSLCertificateChainFile.*|SSLCertificateChainFile /etc/ssl/panovision/panovision-chain.crt|' "$APACHE_CONF"
    else
        # Add chain certificate line after SSLCertificateKeyFile
        sed -i '/SSLCertificateKeyFile/a SSLCertificateChainFile /etc/ssl/panovision/panovision-chain.crt' "$APACHE_CONF"
    fi
    echo "✓ Updated Apache config to use chain certificate"
fi

echo "✓ Updated Apache configuration"

# Test Apache configuration
echo ""
echo "8. Testing Apache configuration..."
if httpd -t 2>&1; then
    echo "✓ Apache configuration is valid"
else
    echo "✗ Apache configuration test failed"
    echo "Restoring backup configuration..."
    cp "$BACKUP_CONF" "$APACHE_CONF"
    httpd -t
    exit 1
fi

# Restart Apache
echo ""
echo "9. Restarting Apache..."
systemctl restart httpd
sleep 2

if systemctl is-active --quiet httpd; then
    echo "✓ Apache restarted successfully"
else
    echo "✗ Apache failed to restart"
    systemctl status httpd --no-pager -l | head -20
    exit 1
fi

# Final summary
echo ""
echo "=========================================="
echo "SSL Certificate Installation Complete!"
echo "=========================================="
echo ""
echo "Certificate files:"
echo "  Certificate: $SSL_DIR/panovision.crt"
echo "  Private Key: $SSL_DIR/panovision.key"
if [ -f "$SSL_DIR/panovision-chain.crt" ]; then
    echo "  Chain Certificate: $SSL_DIR/panovision-chain.crt"
fi
echo ""
echo "Apache configuration: $APACHE_CONF"
echo ""
echo "To verify SSL is working:"
echo "  openssl s_client -connect your-server:443 -showcerts"
echo ""
echo "To check certificate expiration:"
echo "  openssl x509 -in $SSL_DIR/panovision.crt -noout -dates"
echo ""
