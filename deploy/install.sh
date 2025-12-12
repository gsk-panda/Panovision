#!/bin/bash

set -e

GITHUB_REPO="https://github.com/gsk-panda/New-Panovision.git"
INSTALL_DIR="/opt/New-Panovision"

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
echo "Step $NEXT_STEP: Building application..."
npm run build

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
cp "$NGINX_CONFIG_SOURCE" "$NGINX_CONF"

echo ""
echo "Setting up self-signed SSL certificate..."
SSL_DIR="/etc/ssl/panovision"
mkdir -p "$SSL_DIR"

if [ ! -f "$SSL_DIR/panovision-selfsigned.crt" ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$SSL_DIR/panovision-selfsigned.key" \
        -out "$SSL_DIR/panovision-selfsigned.crt" \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=panovision.officeours.com" 2>/dev/null
    
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
echo ""
echo "Next steps:"
echo "1. Configure DNS to point panovision.officeours.com to this server"
echo "2. Access: https://panovision.officeours.com (browser will warn about self-signed cert)"
echo ""
echo "To check Nginx status: systemctl status nginx"
echo "To view logs: tail -f /var/log/nginx/panovision-error.log"
echo ""
echo "To update the application:"
echo "  cd $PROJECT_DIR"
echo "  git pull"
echo "  ./deploy/update.sh"
echo ""

