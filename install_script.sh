#!/bin/bash

################################################################################
# New-Panovision Installation Script for RHEL 9
# Supports OIDC Authentication (Optional)
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
APP_DIR="/opt/panovision"
APP_USER="panovision"
APP_PORT="3000"
NODE_VERSION="20"

# Function to print colored messages
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run this script as root or with sudo"
    exit 1
fi

print_message "Starting New-Panovision installation on RHEL 9..."

################################################################################
# Step 1: Install System Dependencies
################################################################################
print_message "Installing system dependencies..."

# Enable EPEL repository
dnf install -y epel-release

# Update system
dnf update -y

# Install required packages
dnf install -y \
    git \
    nginx \
    firewalld \
    policycoreutils-python-utils \
    openssl

# Install Node.js
print_message "Installing Node.js ${NODE_VERSION}..."
dnf module reset -y nodejs
dnf module enable -y nodejs:${NODE_VERSION}
dnf install -y nodejs npm

# Verify Node.js installation
NODE_INSTALLED=$(node --version)
print_message "Node.js ${NODE_INSTALLED} installed successfully"

################################################################################
# Step 2: Create Application User
################################################################################
print_message "Creating application user..."

if ! id -u ${APP_USER} >/dev/null 2>&1; then
    useradd -r -m -d ${APP_DIR} -s /bin/bash ${APP_USER}
    print_message "User ${APP_USER} created"
else
    print_warning "User ${APP_USER} already exists"
fi

################################################################################
# Step 3: Clone Repository
################################################################################
print_message "Cloning New-Panovision repository..."

if [ ! -d "${APP_DIR}/app" ]; then
    sudo -u ${APP_USER} git clone https://github.com/gsk-panda/New-Panovision.git ${APP_DIR}/app
else
    print_warning "Repository already exists at ${APP_DIR}/app"
    cd ${APP_DIR}/app
    sudo -u ${APP_USER} git pull
fi

cd ${APP_DIR}/app

################################################################################
# Step 4: Create .env Configuration File
################################################################################
print_message "Creating environment configuration..."

cat > ${APP_DIR}/app/.env <<'EOF'
# Gemini API Configuration
GEMINI_API_KEY=your_gemini_api_key_here

# Application Configuration
PORT=3000
NODE_ENV=production

# OIDC Configuration (Enable/Disable)
# Set to 'true' to enable OIDC authentication, 'false' to disable
ENABLE_OIDC=false

# OIDC Settings (Required if ENABLE_OIDC=true)
OIDC_ISSUER_URL=https://your-oidc-provider.com
OIDC_CLIENT_ID=your_client_id
OIDC_CLIENT_SECRET=your_client_secret
OIDC_REDIRECT_URI=http://localhost:3000/auth/callback
OIDC_SCOPE=openid profile email

# Session Secret (Required if ENABLE_OIDC=true)
SESSION_SECRET=change_this_to_a_random_string

# Additional OIDC Options
OIDC_POST_LOGOUT_REDIRECT_URI=http://localhost:3000
OIDC_RESPONSE_TYPE=code
OIDC_RESPONSE_MODE=query
EOF

chown ${APP_USER}:${APP_USER} ${APP_DIR}/app/.env
chmod 600 ${APP_DIR}/app/.env

print_message "Environment file created at ${APP_DIR}/app/.env"
print_warning "IMPORTANT: Edit ${APP_DIR}/app/.env and configure your settings!"

################################################################################
# Step 5: Install Node.js Dependencies
################################################################################
print_message "Installing Node.js dependencies..."

cd ${APP_DIR}/app
sudo -u ${APP_USER} npm install

################################################################################
# Step 6: Build Application
################################################################################
print_message "Building application..."

sudo -u ${APP_USER} npm run build

################################################################################
# Step 7: Create Systemd Service
################################################################################
print_message "Creating systemd service..."

cat > /etc/systemd/system/panovision.service <<EOF
[Unit]
Description=New-Panovision Application
After=network.target

[Service]
Type=simple
User=${APP_USER}
WorkingDirectory=${APP_DIR}/app
Environment=NODE_ENV=production
EnvironmentFile=${APP_DIR}/app/.env
ExecStart=/usr/bin/npm run preview
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=panovision

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable panovision.service

################################################################################
# Step 8: Configure Nginx Reverse Proxy
################################################################################
print_message "Configuring Nginx..."

cat > /etc/nginx/conf.d/panovision.conf <<EOF
server {
    listen 80;
    server_name _;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    location / {
        proxy_pass http://localhost:${APP_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Test Nginx configuration
nginx -t

################################################################################
# Step 9: Configure Firewall
################################################################################
print_message "Configuring firewall..."

systemctl start firewalld
systemctl enable firewalld

firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload

################################################################################
# Step 10: Configure SELinux
################################################################################
print_message "Configuring SELinux..."

if [ "$(getenforce)" != "Disabled" ]; then
    setsebool -P httpd_can_network_connect 1
    semanage port -a -t http_port_t -p tcp ${APP_PORT} 2>/dev/null || \
    semanage port -m -t http_port_t -p tcp ${APP_PORT}
fi

################################################################################
# Step 11: Start Services
################################################################################
print_message "Starting services..."

systemctl start panovision
systemctl start nginx

################################################################################
# Step 12: Display Status and Next Steps
################################################################################
print_message "Installation completed successfully!"
echo ""
print_message "Service Status:"
systemctl status panovision --no-pager -l || true
echo ""
print_message "Next Steps:"
echo "1. Edit the configuration file: ${APP_DIR}/app/.env"
echo "   - Set your GEMINI_API_KEY"
echo "   - Configure OIDC settings if ENABLE_OIDC=true"
echo ""
echo "2. Restart the service after configuration:"
echo "   sudo systemctl restart panovision"
echo ""
echo "3. Check service logs:"
echo "   sudo journalctl -u panovision -f"
echo ""
echo "4. Access the application:"
echo "   http://$(hostname -I | awk '{print $1}')"
echo ""

if [ -f "${APP_DIR}/app/.env" ]; then
    OIDC_ENABLED=$(grep "^ENABLE_OIDC=" ${APP_DIR}/app/.env | cut -d'=' -f2)
    if [ "$OIDC_ENABLED" = "true" ]; then
        print_warning "OIDC is ENABLED - Make sure to configure OIDC settings in .env"
    else
        print_message "OIDC is DISABLED - Application will run without authentication"
    fi
fi

print_message "For SSL/HTTPS setup, consider using Let's Encrypt certbot"
echo ""
