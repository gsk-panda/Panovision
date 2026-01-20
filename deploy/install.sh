#!/bin/bash

set -e

# PanoVision Installation Script - Complete Version with All Fixes
# This script includes all fixes discovered during deployment

GITHUB_REPO="https://github.com/your-org/Panovision.git"
INSTALL_DIR="/opt/Panovision"
OIDC_ENABLED="false"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --disable-oidc|--no-oidc)
            OIDC_ENABLED="false"
            shift
            ;;
        --enable-oidc)
            OIDC_ENABLED="true"
            shift
            ;;
        -h|--help)
            echo "PanoVision Installation Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --disable-oidc, --no-oidc    Disable OIDC authentication (default, allows anonymous access)"
            echo "  --enable-oidc                Enable OIDC authentication"
            echo "  -h, --help                   Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  VITE_OIDC_ENABLED           Set to 'false' to disable OIDC (overrides --disable-oidc)"
            echo "  JFROG_REPO_URL              JFrog repository URL for Node.js installation"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

if [ -n "$VITE_OIDC_ENABLED" ]; then
    OIDC_ENABLED="$VITE_OIDC_ENABLED"
fi

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
echo "=========================================="
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    exit 1
fi

# Configuration
echo "=========================================="
echo "Configuration"
echo "=========================================="
echo ""

read -p "Server URL or IP (e.g., panovision.example.com or 192.168.1.100): " SERVER_URL
SERVER_URL=${SERVER_URL:-panovision.example.com}

read -p "Panorama IP or URL (e.g., panorama.example.com or 192.168.1.50): " PANORAMA_URL
PANORAMA_URL=${PANORAMA_URL:-panorama.example.com}

if [[ ! "$PANORAMA_URL" =~ ^https?:// ]]; then
    PANORAMA_URL="https://$PANORAMA_URL"
fi

PANORAMA_HOST=$(echo "$PANORAMA_URL" | sed 's|https\?://||' | sed 's|/.*||')

read -p "Panorama API Key: " PANORAMA_API_KEY
if [ -z "$PANORAMA_API_KEY" ]; then
    echo "Warning: API Key is required for the application to function"
    read -p "Panorama API Key (required): " PANORAMA_API_KEY
    if [ -z "$PANORAMA_API_KEY" ]; then
        echo "Error: API Key cannot be empty"
        exit 1
    fi
fi

# OIDC Configuration (if enabled)
AZURE_CLIENT_ID=""
AZURE_AUTHORITY=""
AZURE_REDIRECT_URI=""

if [ "$OIDC_ENABLED" != "false" ] && [ "$OIDC_ENABLED" != "0" ]; then
    echo ""
    echo "Azure OIDC Configuration (required for OIDC authentication):"
    echo "Leave blank to disable OIDC and allow anonymous access"
    echo ""
    read -p "Azure Client ID (VITE_AZURE_CLIENT_ID): " AZURE_CLIENT_ID
    read -p "Azure Authority (e.g., https://login.microsoftonline.com/tenant-id): " AZURE_AUTHORITY
    
    if [ -z "$AZURE_CLIENT_ID" ] || [ -z "$AZURE_AUTHORITY" ]; then
        echo ""
        echo "Azure OIDC configuration incomplete. OIDC will be disabled."
        OIDC_ENABLED="false"
        AZURE_CLIENT_ID=""
        AZURE_AUTHORITY=""
        AZURE_REDIRECT_URI=""
    else
        read -p "Azure Redirect URI (default: https://$SERVER_URL): " AZURE_REDIRECT_URI
        AZURE_REDIRECT_URI=${AZURE_REDIRECT_URI:-https://$SERVER_URL}
        echo ""
        echo "OIDC will be enabled with:"
        echo "  Client ID: ${AZURE_CLIENT_ID:0:20}... (hidden)"
        echo "  Authority: $AZURE_AUTHORITY"
        echo "  Redirect URI: $AZURE_REDIRECT_URI"
    fi
else
    echo ""
    echo "OIDC authentication is disabled - application will allow anonymous access"
fi

# Node.js installation method
echo ""
echo "Node.js Installation Method:"
echo "  1) JFrog Repository (recommended if NodeSource is blocked)"
echo "  2) NodeSource (default, may be blocked by proxy)"
read -p "Choose method [1-2] (default: 1): " NODE_INSTALL_METHOD
NODE_INSTALL_METHOD=${NODE_INSTALL_METHOD:-1}

JFROG_REPO_URL=""
if [ "$NODE_INSTALL_METHOD" = "1" ]; then
    read -p "JFrog Repository URL (default: https://jfrog.example.com/artifactory/repo-name/repofiles/rhel/rocky9.repo): " JFROG_REPO_URL
    JFROG_REPO_URL=${JFROG_REPO_URL:-https://jfrog.example.com/artifactory/repo-name/repofiles/rhel/rocky9.repo}
fi

echo ""
echo "=========================================="
echo "Starting Installation"
echo "=========================================="
echo ""

NEXT_STEP=1

# Step 1: System preparation
echo "Step $NEXT_STEP: Preparing system..."
NEXT_STEP=$((NEXT_STEP + 1))

# Disable NodeSource repos if using JFrog
if [ "$NODE_INSTALL_METHOD" = "1" ] && [ -n "$JFROG_REPO_URL" ]; then
    echo "Disabling NodeSource repositories to prevent proxy conflicts..."
    for repo_file in /etc/yum.repos.d/nodesource*.repo; do
        if [ -f "$repo_file" ]; then
            sed -i 's/^enabled=1/enabled=0/' "$repo_file" 2>/dev/null || true
            echo "Disabled: $repo_file"
        fi
    done
fi

# Clean DNF cache
echo "Cleaning DNF cache..."
dnf clean all >/dev/null 2>&1 || true

# Resolve OpenSSL FIPS provider conflict
echo "Resolving OpenSSL FIPS provider conflict..."
if rpm -q openssl-fips-provider-so >/dev/null 2>&1; then
    echo "Detected OpenSSL FIPS provider conflict, attempting to resolve..."
    dnf clean all >/dev/null 2>&1 || true
    dnf makecache -y >/dev/null 2>&1 || true
    
    # Try to upgrade OpenSSL packages
    dnf upgrade -y openssl* --allowerasing --best >/dev/null 2>&1 || {
        echo "Attempting to upgrade systemd and OpenSSL together..."
        dnf upgrade -y systemd openssl* --allowerasing --best >/dev/null 2>&1 || {
            echo "Warning: OpenSSL conflict may persist, continuing..."
        }
    }
fi

# Update system packages
echo "Updating system packages..."
if [ "$NODE_INSTALL_METHOD" = "1" ] && [ -n "$JFROG_REPO_URL" ]; then
    dnf update -y --disablerepo=nodesource* --allowerasing --best >/dev/null 2>&1 || {
        dnf update -y --disablerepo=nodesource* --allowerasing >/dev/null 2>&1 || {
            dnf update -y --disablerepo=nodesource* >/dev/null 2>&1 || dnf update -y
        }
    }
else
    dnf update -y --allowerasing --best >/dev/null 2>&1 || {
        dnf update -y --allowerasing >/dev/null 2>&1 || dnf update -y
    }
fi

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
    if [ "$NODE_INSTALL_METHOD" = "1" ] && [ -n "$JFROG_REPO_URL" ]; then
        echo "Installing Node.js from JFrog repository..."
        echo "JFrog Repository URL: $JFROG_REPO_URL"
        
        REPO_FILE_NAME=$(basename "$JFROG_REPO_URL")
        REPO_FILE_PATH="/etc/yum.repos.d/${REPO_FILE_NAME}"
        
        echo "Downloading repository file from JFrog..."
        if curl -f -s -o "$REPO_FILE_PATH" "$JFROG_REPO_URL" 2>/dev/null; then
            if [ -f "$REPO_FILE_PATH" ] && [ -s "$REPO_FILE_PATH" ]; then
                echo "✓ Repository file downloaded: $REPO_FILE_PATH"
                
                echo "Refreshing DNF cache..."
                dnf makecache -y >/dev/null 2>&1 || true
                
                echo "Installing Node.js from JFrog repository..."
                dnf install -y nodejs npm || {
                    echo "Error: Failed to install Node.js from JFrog repository"
                    exit 1
                }
            else
                echo "Error: Downloaded repository file is empty or invalid"
                rm -f "$REPO_FILE_PATH"
                exit 1
            fi
        else
            echo "Error: Could not download repository file from JFrog"
            exit 1
        fi
    else
        echo "Installing Node.js from NodeSource..."
        if curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash -; then
            echo "✓ NodeSource repository added"
            dnf install -y nodejs
        else
            echo "Error: Failed to add NodeSource repository"
            echo "This may be due to proxy/firewall restrictions"
            echo "Consider using JFrog repository method (option 1) instead"
            exit 1
        fi
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

# On RHEL 9.7, modules are included in httpd package and enabled via config
# mod_proxy, mod_proxy_http, mod_rewrite, mod_deflate, mod_headers are all included
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

# Set OpenSSL legacy provider for Node.js 17+
export NODE_OPTIONS="--openssl-legacy-provider"

# Create environment file
cat > "$PROJECT_DIR/.env" <<EOF
VITE_PANORAMA_SERVER=$PANORAMA_URL
VITE_OIDC_ENABLED=$OIDC_ENABLED
EOF

# Add Azure OIDC configuration if provided
if [ "$OIDC_ENABLED" != "false" ] && [ "$OIDC_ENABLED" != "0" ] && [ -n "$AZURE_CLIENT_ID" ]; then
    cat >> "$PROJECT_DIR/.env" <<EOF
VITE_AZURE_CLIENT_ID=$AZURE_CLIENT_ID
VITE_AZURE_AUTHORITY=$AZURE_AUTHORITY
VITE_AZURE_REDIRECT_URI=$AZURE_REDIRECT_URI
EOF
fi

# Build with OIDC setting
if [ "$OIDC_ENABLED" = "false" ] || [ "$OIDC_ENABLED" = "0" ]; then
    echo "Building with OIDC disabled..."
    export VITE_OIDC_ENABLED=false
else
    echo "Building with OIDC enabled..."
    export VITE_OIDC_ENABLED=true
    if [ -n "$AZURE_CLIENT_ID" ]; then
        export VITE_AZURE_CLIENT_ID="$AZURE_CLIENT_ID"
        export VITE_AZURE_AUTHORITY="$AZURE_AUTHORITY"
        export VITE_AZURE_REDIRECT_URI="$AZURE_REDIRECT_URI"
    fi
fi

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

# Fix permissions for API proxy
mkdir -p "$PROJECT_DIR/deploy"
chmod 755 "$PROJECT_DIR/deploy"
chmod 644 "$PROJECT_DIR/deploy/api-proxy.js"
chown -R panovision:panovision "$PROJECT_DIR/deploy"

# Set SELinux context if SELinux is enabled
if command -v getenforce &>/dev/null && [ "$(getenforce)" != "Disabled" ]; then
    chcon -t bin_t "$PROJECT_DIR/deploy/api-proxy.js" 2>/dev/null || true
fi

# Install systemd service
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

# Stop Apache and Nginx (if running) and check for port conflicts
echo "Stopping Apache and Nginx (if running) and checking for port conflicts..."
systemctl stop httpd 2>/dev/null || true
systemctl stop nginx 2>/dev/null || true
pkill -9 httpd 2>/dev/null || true
pkill -9 nginx 2>/dev/null || true
sleep 2

# Remove old Apache configurations
echo "Removing old Apache configurations..."
APACHE_CONF_DIR="/etc/httpd/conf.d"
APACHE_BACKUP_DIR="/etc/httpd/conf.d/backups"
mkdir -p "$APACHE_BACKUP_DIR"

# Backup and remove old panovision configurations
if [ -f "$APACHE_CONF" ]; then
    BACKUP_FILE="${APACHE_BACKUP_DIR}/panovision.conf.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$APACHE_CONF" "$BACKUP_FILE"
    echo "✓ Backed up old configuration to: $BACKUP_FILE"
    rm -f "$APACHE_CONF"
    echo "✓ Removed old configuration: $APACHE_CONF"
fi

# Remove any other old panovision-related configs
for old_conf in "$APACHE_CONF_DIR"/panovision*.conf "$APACHE_CONF_DIR"/*panovision*.conf; do
    if [ -f "$old_conf" ] && [ "$old_conf" != "$APACHE_CONF" ]; then
        BACKUP_FILE="${APACHE_BACKUP_DIR}/$(basename "$old_conf").backup.$(date +%Y%m%d_%H%M%S)"
        cp "$old_conf" "$BACKUP_FILE"
        echo "✓ Backed up old configuration to: $BACKUP_FILE"
        rm -f "$old_conf"
        echo "✓ Removed old configuration: $old_conf"
    fi
done

# Remove old Nginx configurations if they exist
echo "Removing old Nginx configurations..."
NGINX_CONF_DIR="/etc/nginx/conf.d"
if [ -d "$NGINX_CONF_DIR" ]; then
    for old_conf in "$NGINX_CONF_DIR"/panovision*.conf; do
        if [ -f "$old_conf" ]; then
            BACKUP_FILE="${APACHE_BACKUP_DIR}/nginx-$(basename "$old_conf").backup.$(date +%Y%m%d_%H%M%S)"
            cp "$old_conf" "$BACKUP_FILE"
            rm -f "$old_conf"
            echo "✓ Removed old Nginx configuration: $old_conf"
        fi
    done
fi

echo "✓ Old configurations removed"

# Check if ports 80 and 443 are free
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

# Copy Apache configuration
APACHE_CONFIG_SOURCE="$PROJECT_DIR/deploy/apache-panovision.conf"
if [ ! -f "$APACHE_CONFIG_SOURCE" ]; then
    echo "Error: Apache configuration file not found at $APACHE_CONFIG_SOURCE"
    exit 1
fi

# Update server name in config
sed "s|panovision.example.com|$SERVER_URL|g" "$APACHE_CONFIG_SOURCE" > "$APACHE_CONF"
echo "✓ Apache configuration updated with server name: $SERVER_URL"

# Ensure required modules are enabled in main config
MAIN_CONF="/etc/httpd/conf/httpd.conf"
if [ -f "$MAIN_CONF" ]; then
    # Check if modules need to be enabled
    if grep -q "^#LoadModule rewrite_module" "$MAIN_CONF"; then
        echo "Enabling required modules in main Apache config..."
        sed -i 's/^#LoadModule rewrite_module/LoadModule rewrite_module/' "$MAIN_CONF"
        sed -i 's/^#LoadModule proxy_module/LoadModule proxy_module/' "$MAIN_CONF"
        sed -i 's/^#LoadModule proxy_http_module/LoadModule proxy_http_module/' "$MAIN_CONF"
        sed -i 's/^#LoadModule deflate_module/LoadModule deflate_module/' "$MAIN_CONF"
        sed -i 's/^#LoadModule headers_module/LoadModule headers_module/' "$MAIN_CONF"
        echo "✓ Modules enabled in main config"
    else
        echo "✓ Modules already enabled or configured"
    fi
fi

# Create SSL certificates
echo "Creating SSL certificates..."
SSL_DIR="/etc/ssl/panovision"
mkdir -p "$SSL_DIR"

if [ ! -f "$SSL_DIR/panovision-selfsigned.crt" ] || [ ! -f "$SSL_DIR/panovision-selfsigned.key" ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$SSL_DIR/panovision-selfsigned.key" \
        -out "$SSL_DIR/panovision-selfsigned.crt" \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=$SERVER_URL" 2>/dev/null
    
    chmod 600 "$SSL_DIR/panovision-selfsigned.key"
    chmod 644 "$SSL_DIR/panovision-selfsigned.crt"
    echo "✓ SSL certificates created"
else
    echo "✓ SSL certificates already exist"
fi

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
    
    # Check if ports are listening
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
echo "Server URL: $SERVER_URL"
echo "Panorama URL: $PANORAMA_URL"
if [ "$OIDC_ENABLED" = "false" ] || [ "$OIDC_ENABLED" = "0" ]; then
    echo "OIDC Authentication: DISABLED (anonymous access)"
else
    echo "OIDC Authentication: ENABLED"
    if [ -n "$AZURE_CLIENT_ID" ]; then
        echo "Azure Client ID: ${AZURE_CLIENT_ID:0:20}... (hidden)"
        echo "Azure Authority: $AZURE_AUTHORITY"
        echo "Azure Redirect URI: $AZURE_REDIRECT_URI"
    fi
fi
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
echo "To generate a CSR for a proper SSL certificate:"
echo "  cd $PROJECT_DIR"
echo "  sudo ./deploy/generate-apache-csr.sh"
echo ""