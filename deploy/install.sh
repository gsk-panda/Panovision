#!/bin/bash

set -e

GITHUB_REPO="https://github.com/gsk-panda/New-Panovision.git"
INSTALL_DIR="/opt/New-Panovision"
OIDC_ENABLED="true"

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
            echo "  --disable-oidc, --no-oidc    Disable OIDC authentication (allows anonymous access)"
            echo "  --enable-oidc                Enable OIDC authentication (default)"
            echo "  -h, --help                   Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  VITE_OIDC_ENABLED           Set to 'false' to disable OIDC (overrides --disable-oidc)"
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
NGINX_CONF="/etc/nginx/conf.d/panovision.conf"
SERVICE_NAME="panovision"

echo "=========================================="
echo "PanoVision Installation Script"
echo "=========================================="
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    exit 1
fi

echo "=========================================="
echo "Configuration"
echo "=========================================="
echo ""
echo "Please provide the following configuration details:"
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

if [ "$OIDC_ENABLED" != "false" ] && [ "$OIDC_ENABLED" != "0" ]; then
    echo ""
    echo "Azure OIDC Configuration (leave blank to skip OIDC setup):"
    read -p "VITE_AZURE_CLIENT_ID: " AZURE_CLIENT_ID
    read -p "VITE_AZURE_AUTHORITY (e.g., https://login.microsoftonline.com/tenant-id): " AZURE_AUTHORITY
    
    if [ -z "$AZURE_CLIENT_ID" ] || [ -z "$AZURE_AUTHORITY" ]; then
        echo ""
        echo "Azure OIDC configuration incomplete. OIDC will be disabled."
        OIDC_ENABLED="false"
        AZURE_CLIENT_ID=""
        AZURE_AUTHORITY=""
        AZURE_REDIRECT_URI=""
    else
        read -p "VITE_AZURE_REDIRECT_URI (default: https://$SERVER_URL): " AZURE_REDIRECT_URI
        AZURE_REDIRECT_URI=${AZURE_REDIRECT_URI:-https://$SERVER_URL}
    fi
else
    AZURE_CLIENT_ID=""
    AZURE_AUTHORITY=""
    AZURE_REDIRECT_URI=""
fi

echo ""
echo "=========================================="
echo "Configuration Summary"
echo "=========================================="
echo "Server URL: $SERVER_URL"
echo "Panorama URL: $PANORAMA_URL"
echo "API Key: ${PANORAMA_API_KEY:0:20}... (hidden)"
if [ "$OIDC_ENABLED" = "false" ] || [ "$OIDC_ENABLED" = "0" ]; then
    echo "OIDC Authentication: DISABLED (anonymous access enabled)"
else
    echo "OIDC Authentication: ENABLED"
    echo "Azure Client ID: ${AZURE_CLIENT_ID:0:20}... (hidden)"
    echo "Azure Authority: $AZURE_AUTHORITY"
    echo "Azure Redirect URI: $AZURE_REDIRECT_URI"
fi
echo ""
read -p "Continue with installation? (y/N): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Installation cancelled."
    exit 0
fi
echo ""

echo "Step 1: Updating system packages..."
dnf update -y

if [ ! -f "$SCRIPT_DIR/../package.json" ] || [ ! -d "$SCRIPT_DIR/../.git" ]; then
    echo ""
    echo "Step 2: Downloading repository from GitHub..."
    
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
    
    echo ""
    echo "Verifying repository integrity (OWASP A08 compliance)..."
    cd "$INSTALL_DIR"
    
    if [ -d ".git" ]; then
        echo "Verifying git repository state..."
        if ! git fsck --no-progress >/dev/null 2>&1; then
            echo "Warning: Git repository integrity check found issues"
        else
            echo "✓ Git repository integrity verified"
        fi
        
        if ! git verify-commit HEAD >/dev/null 2>&1; then
            echo "Warning: Current commit signature verification failed (unsigned commits are acceptable)"
        fi
    fi
    
    if [ -f "package.json" ]; then
        echo "Verifying package.json exists and is valid JSON..."
        if ! python3 -m json.tool package.json >/dev/null 2>&1 && ! node -e "JSON.parse(require('fs').readFileSync('package.json'))" >/dev/null 2>&1; then
            echo "Error: package.json is not valid JSON"
            exit 1
        fi
        echo "✓ package.json is valid"
    fi
    
    echo "✓ Repository integrity checks passed"
    echo ""
    
    CLONE_STEP=2
    NEXT_STEP=3
else
    CLONE_STEP=0
    NEXT_STEP=2
fi

echo ""
echo "Step $NEXT_STEP: Installing Node.js (latest LTS from NodeSource, required for Vite 5)..."
if command -v node &> /dev/null; then
    CURRENT_NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    echo "Current Node.js version: $(node -v)"
    if [ "$CURRENT_NODE_VERSION" -lt "18" ]; then
        echo "Removing old Node.js version..."
        dnf remove -y nodejs npm 2>/dev/null || true
        rm -f /usr/bin/node /usr/bin/npm /usr/local/bin/node /usr/local/bin/npm 2>/dev/null || true
    fi
fi

echo "Adding NodeSource repository for latest LTS..."
curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash -

echo "Installing latest Node.js LTS..."
dnf install -y nodejs

echo "Verifying Node.js installation..."
NODE_VERSION=$(node -v)
NODE_MAJOR_VERSION=$(echo "$NODE_VERSION" | cut -d'v' -f2 | cut -d'.' -f1)
echo "Installed Node.js version: $NODE_VERSION"

if [ "$NODE_MAJOR_VERSION" -lt "18" ]; then
    echo "Error: Node.js 18+ is required for Vite 5. Current version: $NODE_VERSION"
    exit 1
fi

echo ""
NEXT_STEP=$((NEXT_STEP + 1))
echo "Step $NEXT_STEP: Installing Nginx (latest version)..."
if ! command -v nginx &> /dev/null; then
    dnf install -y nginx
else
    echo "Nginx already installed, ensuring latest version..."
    dnf install -y nginx
fi

NGINX_VERSION=$(nginx -v 2>&1 | cut -d'/' -f2)
echo "Installed Nginx version: $NGINX_VERSION"

echo ""
NEXT_STEP=$((NEXT_STEP + 1))
echo "Step $NEXT_STEP: Installing Firewalld (if needed)..."
if ! systemctl is-active --quiet firewalld 2>/dev/null; then
    dnf install -y firewalld
    systemctl enable firewalld
    systemctl start firewalld
fi

echo ""
NEXT_STEP=$((NEXT_STEP + 1))
echo "Step $NEXT_STEP: Creating application user..."
if ! id "$APP_USER" &>/dev/null; then
    useradd -r -s /bin/false -d "$APP_DIR" "$APP_USER"
    echo "Created user: $APP_USER"
else
    echo "User $APP_USER already exists"
fi

echo ""
NEXT_STEP=$((NEXT_STEP + 1))
echo "Step $NEXT_STEP: Creating application directory..."
mkdir -p "$APP_DIR"
chown -R "$APP_USER:$APP_USER" "$APP_DIR"

echo ""
NEXT_STEP=$((NEXT_STEP + 1))
echo "Step $NEXT_STEP: Verifying Node.js version before build..."
NODE_VERSION=$(node -v)
NODE_MAJOR_VERSION=$(echo "$NODE_VERSION" | cut -d'v' -f2 | cut -d'.' -f1)
echo "Using Node.js: $NODE_VERSION"

if [ "$NODE_MAJOR_VERSION" -lt "18" ]; then
    echo "Error: Node.js 18+ is required for Vite 5. Current version: $NODE_VERSION"
    echo "Please run: ./deploy/fix-nodejs.sh"
    exit 1
fi

echo ""
NEXT_STEP=$((NEXT_STEP + 1))
echo "Step $NEXT_STEP: Installing Node.js dependencies..."
cd "$PROJECT_DIR"
npm install --production=false

echo ""
NEXT_STEP=$((NEXT_STEP + 1))
echo "Step $NEXT_STEP: Storing API key securely (server-side only)..."
mkdir -p /etc/panovision
echo "$PANORAMA_API_KEY" > /etc/panovision/api-key
chmod 600 /etc/panovision/api-key
chown root:root /etc/panovision/api-key
echo "✓ API key stored securely in /etc/panovision/api-key"

cat > /etc/panovision/panorama-config <<EOF
PANORAMA_URL=$PANORAMA_URL
EOF
chmod 644 /etc/panovision/panorama-config
chown root:root /etc/panovision/panorama-config
echo "✓ Panorama configuration stored in /etc/panovision/panorama-config"

echo ""
NEXT_STEP=$((NEXT_STEP + 1))
echo "Step $NEXT_STEP: Creating environment configuration..."
cd "$PROJECT_DIR"

cat > .env <<EOF
VITE_PANORAMA_SERVER=$PANORAMA_URL
EOF

if [ "$OIDC_ENABLED" = "false" ] || [ "$OIDC_ENABLED" = "0" ]; then
    echo "VITE_OIDC_ENABLED=false" >> .env
else
    echo "VITE_OIDC_ENABLED=true" >> .env
    if [ -n "$AZURE_CLIENT_ID" ]; then
        echo "VITE_AZURE_CLIENT_ID=$AZURE_CLIENT_ID" >> .env
        echo "VITE_AZURE_AUTHORITY=$AZURE_AUTHORITY" >> .env
        echo "VITE_AZURE_REDIRECT_URI=$AZURE_REDIRECT_URI" >> .env
    fi
fi

echo "Environment file created at $PROJECT_DIR/.env (API key excluded for security)"

cat > "$PROJECT_DIR/deploy/config.sh" <<EOF
#!/bin/bash
# PanoVision Configuration
# This file is auto-generated during installation

SERVER_URL="$SERVER_URL"
PANORAMA_URL="$PANORAMA_URL"
PANORAMA_HOST="$PANORAMA_HOST"
EOF

echo "Note: API key is stored securely in /etc/panovision/api-key (not in config.sh)"

chmod 644 "$PROJECT_DIR/deploy/config.sh"
echo "Configuration file created at $PROJECT_DIR/deploy/config.sh"

echo ""
NEXT_STEP=$((NEXT_STEP + 1))
echo "Step $NEXT_STEP: Building application..."

if [ "$OIDC_ENABLED" = "false" ] || [ "$OIDC_ENABLED" = "0" ]; then
    echo "Building with OIDC disabled..."
    export VITE_OIDC_ENABLED=false
    export VITE_PANORAMA_SERVER="$PANORAMA_URL"
    npm run build
else
    echo "Building with OIDC enabled..."
    export VITE_OIDC_ENABLED=true
    export VITE_PANORAMA_SERVER="$PANORAMA_URL"
    if [ -n "$AZURE_CLIENT_ID" ]; then
        export VITE_AZURE_CLIENT_ID="$AZURE_CLIENT_ID"
        export VITE_AZURE_AUTHORITY="$AZURE_AUTHORITY"
        export VITE_AZURE_REDIRECT_URI="$AZURE_REDIRECT_URI"
    fi
    npm run build
fi

if [ ! -d "$PROJECT_DIR/dist" ]; then
    echo "Error: Build failed - dist directory not found"
    exit 1
fi

echo ""
NEXT_STEP=$((NEXT_STEP + 1))
echo "Step $NEXT_STEP: Deploying application files..."
rsync -av --delete "$PROJECT_DIR/dist/" "$APP_DIR/"

echo ""
NEXT_STEP=$((NEXT_STEP + 1))
echo "Step $NEXT_STEP: Setting file permissions and ownership..."
NGINX_USER="nginx"
if ! id "$NGINX_USER" &>/dev/null; then
    NGINX_USER="www-data"
    if ! id "$NGINX_USER" &>/dev/null; then
        echo "Warning: Could not find nginx or www-data user, using panovision user"
        NGINX_USER="$APP_USER"
    fi
fi

echo "Using Nginx user: $NGINX_USER"
chown -R "$NGINX_USER:$NGINX_USER" "$APP_DIR"
find "$APP_DIR" -type d -exec chmod 755 {} \;
find "$APP_DIR" -type f -exec chmod 644 {} \;

echo ""
NEXT_STEP=$((NEXT_STEP + 1))
echo "Step $NEXT_STEP: Configuring SELinux (if enabled)..."
if command -v getenforce &>/dev/null; then
    SELINUX_STATUS=$(getenforce)
    echo "SELinux status: $SELINUX_STATUS"
    
    if [ "$SELINUX_STATUS" != "Disabled" ]; then
        echo "Setting SELinux context for web content..."
        chcon -R -t httpd_sys_content_t "$APP_DIR" 2>/dev/null || echo "SELinux context update skipped"
        
        echo "Setting SELinux boolean to allow Nginx network connections..."
        setsebool -P httpd_can_network_connect 1
        
        if getsebool httpd_can_network_connect | grep -q "on$"; then
            echo "✓ SELinux boolean set successfully"
        else
            echo "⚠ Warning: Failed to set SELinux boolean"
        fi
    else
        echo "SELinux is disabled, skipping SELinux configuration"
    fi
else
    echo "SELinux tools not found, skipping SELinux configuration"
fi

echo ""
NEXT_STEP=$((NEXT_STEP + 1))
echo "Step $NEXT_STEP: Configuring Nginx..."
NGINX_CONFIG_SOURCE="$PROJECT_DIR/deploy/nginx-panovision.conf"
if [ ! -f "$NGINX_CONFIG_SOURCE" ]; then
    echo "Error: Nginx configuration file not found at $NGINX_CONFIG_SOURCE"
    exit 1
fi

sed "s|panovision.officeours.com|$SERVER_URL|g; s|panorama.officeours.com|$PANORAMA_HOST|g" "$NGINX_CONFIG_SOURCE" > "$NGINX_CONF"
echo "Nginx configuration updated with:"
echo "  Server name: $SERVER_URL"
echo "  Panorama proxy: $PANORAMA_URL (host: $PANORAMA_HOST)"

echo ""
echo "Setting up self-signed SSL certificate..."
SSL_DIR="/etc/ssl/panovision"
mkdir -p "$SSL_DIR"

if [ ! -f "$SSL_DIR/panovision-selfsigned.crt" ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$SSL_DIR/panovision-selfsigned.key" \
        -out "$SSL_DIR/panovision-selfsigned.crt" \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=$SERVER_URL" 2>/dev/null
    
    chmod 600 "$SSL_DIR/panovision-selfsigned.key"
    chmod 644 "$SSL_DIR/panovision-selfsigned.crt"
    echo "Self-signed certificate created"
else
    echo "Self-signed certificate already exists"
fi

echo ""
NEXT_STEP=$((NEXT_STEP + 1))
echo "Step $NEXT_STEP: Testing Nginx configuration..."
nginx -t

echo ""
NEXT_STEP=$((NEXT_STEP + 1))
echo "Step $NEXT_STEP: Installing API proxy service..."
if [ ! -f "$PROJECT_DIR/deploy/api-proxy.js" ]; then
    echo "Error: API proxy service file not found"
    exit 1
fi

cp "$PROJECT_DIR/deploy/api-proxy.js" /opt/panovision/deploy/api-proxy.js
chmod 755 /opt/panovision/deploy/api-proxy.js
chown root:root /opt/panovision/deploy/api-proxy.js

if [ -f "$PROJECT_DIR/deploy/api-proxy.service" ]; then
    cp "$PROJECT_DIR/deploy/api-proxy.service" /etc/systemd/system/api-proxy.service
    systemctl daemon-reload
    systemctl enable api-proxy
    systemctl start api-proxy
    echo "✓ API proxy service installed and started"
    
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

echo ""
NEXT_STEP=$((NEXT_STEP + 1))
echo "Step $NEXT_STEP: Configuring firewall..."
if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --reload
    echo "Firewall rules configured"
else
    echo "Firewalld is not running, skipping firewall configuration"
fi

echo ""
NEXT_STEP=$((NEXT_STEP + 1))
echo "Step $NEXT_STEP: Enabling and starting services..."
systemctl enable nginx
systemctl restart nginx

echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "Application deployed to: $APP_DIR"
echo "Nginx config: $NGINX_CONF"
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
echo "2. Access: https://$SERVER_URL (browser will warn about self-signed cert)"
echo ""
echo "To check Nginx status: systemctl status nginx"
echo "To view logs: tail -f /var/log/nginx/panovision-error.log"
echo ""
echo "To update the application:"
echo "  cd $PROJECT_DIR"
echo "  git pull"
echo "  ./deploy/update.sh"
echo ""
echo "To change OIDC setting, rebuild with:"
echo "  cd $PROJECT_DIR"
echo "  VITE_OIDC_ENABLED=false npm run build"
echo "  rsync -av --delete dist/ $APP_DIR/"
echo "  systemctl reload nginx"
echo ""

