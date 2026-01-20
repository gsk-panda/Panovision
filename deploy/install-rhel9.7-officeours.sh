#!/bin/bash

set -e

# PanoVision Installation Script for RHEL 9.7
# Pre-configured for officeours.com environment

GITHUB_REPO="https://github.com/your-org/Panovision.git"
INSTALL_DIR="/opt/Panovision"
SERVER_URL="panovision.officeours.com"
PANORAMA_URL="https://panorama.officeours.com"
PANORAMA_API_KEY="LUFRPRT1LQWxxdUk4RVVqQ0DQrQkN3TDZtRlBYd0dHUkk5dzczNHg3T0VsRS9yYmFMcEpWdXdBWdFZ4S3JwdDJYeEdLaTNnc2RVV29iQ1BqcnVCRVU1V0VVVHUmF6SUE2VlHIDOA=="
OIDC_ENABLED="false"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/../package.json" ] && [ -d "$SCRIPT_DIR/../.git" ]; then
    PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
    echo "Running from existing repository: $PROJECT_DIR"
else
    PROJECT_DIR="$INSTALL_DIR"
    echo "Standalone mode: Will clone repository from GitHub"
fi

APP_USER="panovision"
APP_DIR="/var/www/panovision"
APACHE_CONF="/etc/httpd/conf.d/panovision.conf"

echo "=========================================="
echo "PanoVision Installation Script"
echo "RHEL 9.7 - officeours.com Configuration"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  Server URL: $SERVER_URL"
echo "  Panorama URL: $PANORAMA_URL"
echo "  OIDC Authentication: DISABLED"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    exit 1
fi

NEXT_STEP=1

# Step 1: System preparation
echo "Step $NEXT_STEP: Preparing system..."
NEXT_STEP=$((NEXT_STEP + 1))

echo "Cleaning DNF cache..."
dnf clean all >/dev/null 2>&1 || true

echo "Resolving OpenSSL FIPS provider conflict..."
if rpm -q openssl-fips-provider-so >/dev/null 2>&1; then
    echo "Detected OpenSSL FIPS provider conflict, attempting to resolve..."
    dnf clean all >/dev/null 2>&1 || true
    dnf makecache -y >/dev/null 2>&1 || true
    
    dnf upgrade -y openssl* --allowerasing --best >/dev/null 2>&1 || {
        echo "Attempting to upgrade systemd and OpenSSL together..."
        dnf upgrade -y systemd openssl* --allowerasing --best >/dev/null 2>&1 || {
            echo "Warning: OpenSSL conflict may persist, continuing..."
        }
    }
fi

echo "Updating system packages..."
dnf update -y --allowerasing --best >/dev/null 2>&1 || {
    dnf update -y --allowerasing >/dev/null 2>&1 || dnf update -y
}

# Step 2: Clone repository if needed
if [ ! -f "$SCRIPT_DIR/../package.json" ] || [ ! -d "$SCRIPT_DIR/../.git" ]; then
    echo ""
    echo "Step $NEXT_STEP: Downloading repository from GitHub..."
    NEXT_STEP=$((NEXT_STEP + 1))
    
    if ! command -v git &> /dev/null; then
        echo "Installing Git..."
        dnf install -y git
    fi
    
    if [ -d "$INSTALL_DIR" ]; then
        echo "Directory $INSTALL_DIR already exists. Removing old installation..."
        rm -rf "$INSTALL_DIR"
    fi
    
    echo "Cloning repository from $GITHUB_REPO..."
    git clone "$GITHUB_REPO" "$INSTALL_DIR"
    
    if [ ! -d "$INSTALL_DIR" ] || [ ! -f "$INSTALL_DIR/package.json" ]; then
        echo "Error: Failed to clone repository or repository is invalid"
        exit 1
    fi
    
    echo "Repository cloned successfully to $INSTALL_DIR"
    PROJECT_DIR="$INSTALL_DIR"
else
    NEXT_STEP=$((NEXT_STEP + 1))
fi

# Step 3: Install Node.js
echo ""
echo "Step $NEXT_STEP: Installing Node.js..."
NEXT_STEP=$((NEXT_STEP + 1))

if command -v node &> /dev/null; then
    CURRENT_NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    echo "Current Node.js version: $(node -v)"
    if [ "$CURRENT_NODE_VERSION" -lt "18" ]; then
        echo "Removing old Node.js version..."
        dnf remove -y nodejs npm 2>/dev/null || true
        rm -f /usr/bin/node /usr/bin/npm /usr/local/bin/node /usr/local/bin/npm 2>/dev/null || true
    else
        echo "Node.js 18+ already installed, skipping installation"
    fi
fi

if ! command -v node &> /dev/null || [ "$CURRENT_NODE_VERSION" -lt "18" ]; then
    echo "Installing Node.js from NodeSource..."
    if curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash -; then
        echo "✓ NodeSource repository added"
        dnf install -y nodejs
    else
        echo "Error: Failed to add NodeSource repository"
        echo "This may be due to proxy/firewall restrictions"
        exit 1
    fi
fi

INSTALLED_NODE_VERSION=$(node -v)
INSTALLED_NODE_MAJOR=$(echo "$INSTALLED_NODE_VERSION" | cut -d'v' -f2 | cut -d'.' -f1)
echo "Installed Node.js version: $INSTALLED_NODE_VERSION"

if [ "$INSTALLED_NODE_MAJOR" -lt "18" ]; then
    echo "Error: Node.js 18+ is required for Vite 5. Current version: $INSTALLED_NODE_VERSION"
    exit 1
fi

# Step 4: Install Apache
echo ""
echo "Step $NEXT_STEP: Installing Apache..."
NEXT_STEP=$((NEXT_STEP + 1))

if ! command -v httpd &> /dev/null; then
    dnf install -y httpd mod_ssl
else
    echo "Apache already installed, ensuring latest version and mod_ssl..."
    dnf install -y httpd mod_ssl
fi

echo "✓ Apache installed (modules are included and will be enabled via configuration)"

APACHE_VERSION=$(httpd -v 2>&1 | head -1 | cut -d'/' -f2 | awk '{print $1}')
echo "Installed Apache version: $APACHE_VERSION"

# Step 5: Install Firewalld
echo ""
echo "Step $NEXT_STEP: Installing Firewalld..."
NEXT_STEP=$((NEXT_STEP + 1))

if ! systemctl is-active --quiet firewalld 2>/dev/null; then
    dnf install -y firewalld
    systemctl enable firewalld
    systemctl start firewalld
fi

# Step 6: Create application user
echo ""
echo "Step $NEXT_STEP: Creating application user..."
NEXT_STEP=$((NEXT_STEP + 1))

if ! id "$APP_USER" &>/dev/null; then
    useradd -r -s /bin/false -d "$APP_DIR" "$APP_USER"
    echo "Created user: $APP_USER"
else
    echo "User $APP_USER already exists"
fi

# Step 7: Create application directory
echo ""
echo "Step $NEXT_STEP: Creating application directory..."
NEXT_STEP=$((NEXT_STEP + 1))

mkdir -p "$APP_DIR"
chown -R "$APP_USER:$APP_USER" "$APP_DIR"

# Step 8: Store API key
echo ""
echo "Step $NEXT_STEP: Storing API key securely..."
NEXT_STEP=$((NEXT_STEP + 1))

mkdir -p /etc/panovision
printf '%s' "$PANORAMA_API_KEY" > /etc/panovision/api-key
chmod 640 /etc/panovision/api-key
chown root:panovision /etc/panovision/api-key
echo "✓ API key stored securely in /etc/panovision/api-key"

# Store Panorama configuration
echo "PANORAMA_URL=$PANORAMA_URL" > /etc/panovision/panorama-config
chmod 644 /etc/panovision/panorama-config
chown root:panovision /etc/panovision/panorama-config

# Step 9: Install dependencies
echo ""
echo "Step $NEXT_STEP: Installing Node.js dependencies..."
NEXT_STEP=$((NEXT_STEP + 1))

cd "$PROJECT_DIR"
npm install --production=false

# Step 10: Build application
echo ""
echo "Step $NEXT_STEP: Building application..."
NEXT_STEP=$((NEXT_STEP + 1))

export NODE_OPTIONS="--openssl-legacy-provider"

# Create environment file
cat > "$PROJECT_DIR/.env" <<EOF
VITE_PANORAMA_SERVER=$PANORAMA_URL
VITE_OIDC_ENABLED=false
EOF

echo "Building with OIDC disabled..."
export VITE_OIDC_ENABLED=false
export VITE_PANORAMA_SERVER="$PANORAMA_URL"
npm run build

if [ ! -d "$PROJECT_DIR/dist" ]; then
    echo "Error: Build failed - dist directory not found"
    exit 1
fi

echo "✓ Build completed successfully"

# Step 11: Deploy files
echo ""
echo "Step $NEXT_STEP: Deploying application files..."
NEXT_STEP=$((NEXT_STEP + 1))

rsync -av --delete "$PROJECT_DIR/dist/" "$APP_DIR/"
chown -R "$APP_USER:$APP_USER" "$APP_DIR"
echo "✓ Files deployed to $APP_DIR"

# Step 12: Configure API proxy service
echo ""
echo "Step $NEXT_STEP: Configuring API proxy service..."
NEXT_STEP=$((NEXT_STEP + 1))

if [ ! -f "$PROJECT_DIR/deploy/api-proxy.js" ]; then
    echo "Error: API proxy service file not found"
    exit 1
fi

mkdir -p "$PROJECT_DIR/deploy"
chmod 755 "$PROJECT_DIR/deploy"
chmod 644 "$PROJECT_DIR/deploy/api-proxy.js"
chown -R panovision:panovision "$PROJECT_DIR/deploy"

if command -v getenforce &>/dev/null && [ "$(getenforce)" != "Disabled" ]; then
    chcon -t bin_t "$PROJECT_DIR/deploy/api-proxy.js" 2>/dev/null || true
fi

if [ -f "$PROJECT_DIR/deploy/api-proxy.service" ]; then
    sed "s|/opt/panovision|$PROJECT_DIR|g" "$PROJECT_DIR/deploy/api-proxy.service" > /tmp/api-proxy.service
    cp /tmp/api-proxy.service /etc/systemd/system/api-proxy.service
    rm -f /tmp/api-proxy.service
    
    systemctl daemon-reload
    systemctl enable api-proxy
    systemctl start api-proxy
    
    sleep 2
    if systemctl is-active --quiet api-proxy; then
        echo "✓ API proxy service is running"
    else
        echo "⚠ Warning: API proxy service failed to start. Check logs: journalctl -u api-proxy"
    fi
else
    echo "Error: API proxy service file not found"
    exit 1
fi

# Step 13: Configure Apache
echo ""
echo "Step $NEXT_STEP: Configuring Apache..."
NEXT_STEP=$((NEXT_STEP + 1))

echo "Stopping Apache and Nginx (if running) and checking for port conflicts..."
systemctl stop httpd 2>/dev/null || true
systemctl stop nginx 2>/dev/null || true
pkill -9 httpd 2>/dev/null || true
pkill -9 nginx 2>/dev/null || true
sleep 2

echo "Removing old Apache configurations..."
APACHE_CONF_DIR="/etc/httpd/conf.d"
APACHE_BACKUP_DIR="/etc/httpd/conf.d/backups"
mkdir -p "$APACHE_BACKUP_DIR"

if [ -f "$APACHE_CONF" ]; then
    BACKUP_FILE="${APACHE_BACKUP_DIR}/panovision.conf.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$APACHE_CONF" "$BACKUP_FILE"
    echo "✓ Backed up old configuration to: $BACKUP_FILE"
    rm -f "$APACHE_CONF"
fi

for old_conf in "$APACHE_CONF_DIR"/panovision*.conf "$APACHE_CONF_DIR"/*panovision*.conf; do
    if [ -f "$old_conf" ] && [ "$old_conf" != "$APACHE_CONF" ]; then
        BACKUP_FILE="${APACHE_BACKUP_DIR}/$(basename "$old_conf").backup.$(date +%Y%m%d_%H%M%S)"
        cp "$old_conf" "$BACKUP_FILE"
        rm -f "$old_conf"
    fi
done

NGINX_CONF_DIR="/etc/nginx/conf.d"
if [ -d "$NGINX_CONF_DIR" ]; then
    for old_conf in "$NGINX_CONF_DIR"/panovision*.conf; do
        if [ -f "$old_conf" ]; then
            BACKUP_FILE="${APACHE_BACKUP_DIR}/nginx-$(basename "$old_conf").backup.$(date +%Y%m%d_%H%M%S)"
            cp "$old_conf" "$BACKUP_FILE"
            rm -f "$old_conf"
        fi
    done
fi

if ss -tlnp | grep ":80" || ss -tlnp | grep ":443"; then
    echo "⚠ Ports 80 and/or 443 are in use:"
    ss -tlnp | grep -E ":80|:443" || true
    echo "Attempting to free ports..."
    systemctl stop httpd 2>/dev/null || true
    systemctl stop nginx 2>/dev/null || true
    pkill -9 httpd 2>/dev/null || true
    pkill -9 nginx 2>/dev/null || true
    sleep 2
    
    if ss -tlnp | grep ":80" || ss -tlnp | grep ":443"; then
        echo "✗ Ports are still in use. Please stop the conflicting service manually."
        exit 1
    fi
fi

# Create Apache configuration for officeours.com
cat > "$APACHE_CONF" <<'APACHE_EOF'
# PanoVision Apache Configuration
# Server: panovision.officeours.com

# HTTP to HTTPS redirect
<VirtualHost *:80>
    ServerName panovision.officeours.com
    
    # Redirect all HTTP traffic to HTTPS
    Redirect permanent / https://panovision.officeours.com/
</VirtualHost>

# HTTPS server block
<VirtualHost *:443>
    ServerName panovision.officeours.com
    
    # Document root
    DocumentRoot /var/www/panovision
    
    # Directory configuration
    <Directory /var/www/panovision>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
        
        # SPA routing - fallback to index.html
        RewriteEngine On
        RewriteBase /
        RewriteRule ^index\.html$ - [L]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule . /index.html [L]
    </Directory>
    
    # SSL Configuration
    SSLEngine on
    SSLCertificateFile /etc/ssl/panovision/panovision-selfsigned.crt
    SSLCertificateKeyFile /etc/ssl/panovision/panovision-selfsigned.key
    
    # SSL Protocol and Cipher Configuration
    SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
    SSLHonorCipherOrder off
    
    # Security Headers
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
    
    # Compression
    <Location />
        SetOutputFilter DEFLATE
        SetEnvIfNoCase Request_URI \
            \.(?:gif|jpe?g|png|ico|svg|woff|woff2|ttf|eot)$ no-gzip dont-vary
    </Location>
    
    # API Proxy - Panorama API endpoints
    ProxyPreserveHost On
    ProxyRequests Off
    
    <Location /api/panorama>
        # Rewrite /api/panorama to /api for the proxy
        RewriteEngine On
        RewriteRule ^/api/panorama(.*)$ /api$1 [P]
        
        # Proxy to API proxy service
        ProxyPass http://127.0.0.1:3001/api
        ProxyPassReverse http://127.0.0.1:3001/api
        
        # Proxy headers
        RequestHeader set Host %{HTTP_HOST}e
        RequestHeader set X-Real-IP %{REMOTE_ADDR}e
        RequestHeader set X-Forwarded-For %{REMOTE_ADDR}e
        RequestHeader set X-Forwarded-Proto "https"
        
        # CORS headers
        Header always set Access-Control-Allow-Origin "*"
        Header always set Access-Control-Allow-Methods "GET, OPTIONS"
        Header always set Access-Control-Allow-Headers "Accept, Content-Type"
        
        # Handle OPTIONS preflight requests
        RewriteCond %{REQUEST_METHOD} OPTIONS
        RewriteRule ^(.*)$ $1 [R=204,L]
    </Location>
    
    # Static assets with long cache
    <LocationMatch "\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|webp)$">
        ExpiresActive On
        ExpiresDefault "access plus 1 year"
        Header set Cache-Control "public, immutable"
    </LocationMatch>
    
    # HTML files - no cache
    <LocationMatch "^/index\.html$">
        Header set Cache-Control "no-cache, no-store, must-revalidate"
        Header set Pragma "no-cache"
        Header set Expires "0"
    </LocationMatch>
    
    # Logging
    ErrorLog /var/log/httpd/panovision-error.log
    CustomLog /var/log/httpd/panovision-access.log combined
</VirtualHost>
APACHE_EOF

echo "✓ Apache configuration created for $SERVER_URL"

# Ensure required modules are enabled in main config
MAIN_CONF="/etc/httpd/conf/httpd.conf"
if [ -f "$MAIN_CONF" ]; then
    if grep -q "^#LoadModule rewrite_module" "$MAIN_CONF"; then
        echo "Enabling required modules in main Apache config..."
        sed -i 's/^#LoadModule rewrite_module/LoadModule rewrite_module/' "$MAIN_CONF"
        sed -i 's/^#LoadModule proxy_module/LoadModule proxy_module/' "$MAIN_CONF"
        sed -i 's/^#LoadModule proxy_http_module/LoadModule proxy_http_module/' "$MAIN_CONF"
        sed -i 's/^#LoadModule deflate_module/LoadModule deflate_module/' "$MAIN_CONF"
        sed -i 's/^#LoadModule headers_module/LoadModule headers_module/' "$MAIN_CONF"
        echo "✓ Modules enabled in main config"
    fi
fi

# Create self-signed SSL certificate for panovision.officeours.com
echo "Creating self-signed SSL certificate for $SERVER_URL..."
SSL_DIR="/etc/ssl/panovision"
mkdir -p "$SSL_DIR"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$SSL_DIR/panovision-selfsigned.key" \
    -out "$SSL_DIR/panovision-selfsigned.crt" \
    -subj "/C=US/ST=State/L=City/O=OfficeOurs/CN=$SERVER_URL" 2>/dev/null

chmod 600 "$SSL_DIR/panovision-selfsigned.key"
chmod 644 "$SSL_DIR/panovision-selfsigned.crt"
echo "✓ Self-signed SSL certificate created for $SERVER_URL"

# Ensure log directories exist
mkdir -p /var/log/httpd
touch /var/log/httpd/panovision-access.log
touch /var/log/httpd/panovision-error.log
chown apache:apache /var/log/httpd/panovision-*.log 2>/dev/null || chown www-data:www-data /var/log/httpd/panovision-*.log 2>/dev/null || true

# Test Apache configuration
echo "Testing Apache configuration..."
if httpd -t 2>&1; then
    echo "✓ Apache configuration is valid"
else
    echo "✗ Apache configuration test failed"
    httpd -t
    exit 1
fi

# Step 14: Configure firewall
echo ""
echo "Step $NEXT_STEP: Configuring firewall..."
NEXT_STEP=$((NEXT_STEP + 1))

if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --reload
    echo "✓ Firewall rules configured"
else
    echo "Firewalld is not running, skipping firewall configuration"
fi

# Step 15: Start services
echo ""
echo "Step $NEXT_STEP: Starting services..."
NEXT_STEP=$((NEXT_STEP + 1))

systemctl enable httpd
systemctl start httpd

sleep 3

# Verify services are running
if systemctl is-active --quiet httpd; then
    echo "✓ Apache is running"
    
    if ss -tlnp | grep httpd | grep ":80"; then
        echo "✓ Port 80 is listening"
    else
        echo "⚠ Port 80 is NOT listening"
    fi
    
    if ss -tlnp | grep httpd | grep ":443"; then
        echo "✓ Port 443 is listening"
    else
        echo "⚠ Port 443 is NOT listening"
        echo "Check error log: tail -f /var/log/httpd/panovision-error.log"
    fi
else
    echo "✗ Apache failed to start"
    systemctl status httpd --no-pager -l | head -20
    exit 1
fi

# Final summary
echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "Application deployed to: $APP_DIR"
echo "Apache config: $APACHE_CONF"
echo "Project directory: $PROJECT_DIR"
echo "Server URL: https://$SERVER_URL"
echo "Panorama URL: $PANORAMA_URL"
echo "OIDC Authentication: DISABLED (anonymous access)"
echo ""
echo "Next steps:"
echo "1. Configure DNS to point $SERVER_URL to this server"
echo "2. Access: https://$SERVER_URL/logs (browser will warn about self-signed cert)"
echo ""
echo "To check service status:"
echo "  systemctl status httpd"
echo "  systemctl status api-proxy"
echo ""
echo "To view logs:"
echo "  tail -f /var/log/httpd/panovision-access.log"
echo "  tail -f /var/log/httpd/panovision-error.log"
echo "  journalctl -u api-proxy -f"
echo ""
echo "If Panorama uses a self-signed certificate, install the CA certificate:"
echo "  cd $PROJECT_DIR"
echo "  sudo ./deploy/fetch-panorama-cert.sh"
echo ""
