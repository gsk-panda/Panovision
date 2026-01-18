# PanoVision Installation Guide

Complete installation guide for deploying PanoVision on RHEL 9.7 with Apache HTTP Server.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation Methods](#installation-methods)
- [Installation Steps](#installation-steps)
- [Post-Installation Configuration](#post-installation-configuration)
- [SSL Certificate Setup](#ssl-certificate-setup)
- [Updating the Application](#updating-the-application)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### System Requirements

- **Operating System**: RHEL 9.7 or compatible (Rocky Linux 9, AlmaLinux 9)
- **Architecture**: x86_64
- **RAM**: Minimum 2GB (4GB recommended)
- **Disk Space**: Minimum 5GB free space
- **Network**: Access to Panorama server and internet (for package installation)

### Network Requirements

- **Ports**: 80 (HTTP) and 443 (HTTPS) must be open
- **DNS**: Domain name configured (optional, can use IP address)
- **Panorama Access**: Network connectivity to Panorama server

### Access Requirements

- **Root or sudo access** to the server
- **SSH access** to the server
- **Panorama API key** with appropriate permissions

## Installation Methods

### Method 1: Git Clone (Recommended)

```bash
ssh root@your-server-ip
cd /opt
git clone https://github.com/gsk-panda/Panovision.git
cd Panovision
sudo chmod +x deploy/install.sh
sudo ./deploy/install.sh
```

### Method 2: Transfer Archive

```bash
# On your local machine
cd /path/to/Panovision
tar -czf panovision-deploy.tar.gz . --exclude='node_modules' --exclude='.git' --exclude='dist'
scp panovision-deploy.tar.gz root@your-server-ip:/opt/

# On the server
ssh root@your-server-ip
cd /opt
tar -xzf panovision-deploy.tar.gz -C Panovision
cd Panovision
sudo chmod +x deploy/install.sh
sudo ./deploy/install.sh
```

## Installation Steps

### Step 1: Run Installation Script

The installation script will guide you through the configuration:

```bash
sudo ./deploy/install.sh
```

### Step 2: Configuration Prompts

The script will prompt for the following information:

#### Server Configuration

- **Server URL or IP**: Enter your server hostname (e.g., `panovision.sncorp.com`) or IP address (e.g., `10.100.5.227`)

#### Panorama Configuration

- **Panorama IP or URL**: Enter your Panorama server address
  - Can be IP: `10.1.0.100`
  - Can be hostname: `panorama.example.com`
  - Can include protocol: `https://10.1.0.100`
- **Panorama API Key**: Enter your Panorama API key

#### Node.js Installation

Choose installation method:
- **Option 1**: JFrog Repository (recommended if NodeSource is blocked by proxy)
- **Option 2**: NodeSource (default, requires internet access)

If using JFrog, provide the repository URL (defaults to provided URL).

#### OIDC Authentication (Optional)

- **Azure Client ID**: Leave blank to disable OIDC (allows anonymous access)
- **Azure Authority**: e.g., `https://login.microsoftonline.com/tenant-id`
- **Azure Redirect URI**: Defaults to `https://your-server-url`

### Step 3: Installation Process

The script will automatically:

1. **Prepare system**: Update packages, resolve conflicts
2. **Install Node.js**: From JFrog or NodeSource repository
3. **Install Apache**: HTTP Server with mod_ssl
4. **Create application user**: `panovision` user account
5. **Store credentials**: Securely store API key and configuration
6. **Install dependencies**: Node.js packages
7. **Build application**: Compile React application
8. **Deploy files**: Copy to `/var/www/panovision`
9. **Configure API proxy**: Set up Node.js proxy service
10. **Configure Apache**: Set up virtual hosts and SSL
11. **Configure firewall**: Open HTTP/HTTPS ports
12. **Start services**: Apache and API proxy

### Step 4: Verify Installation

```bash
# Check Apache status
systemctl status httpd

# Check API proxy status
systemctl status api-proxy

# Check ports are listening
ss -tlnp | grep -E ':(80|443|3001)'

# Test local access
curl -k https://localhost/logs
```

## Post-Installation Configuration

### Panorama Certificate (If Needed)

If your Panorama server uses a self-signed certificate:

```bash
cd /opt/Panovision
sudo ./deploy/fetch-panorama-cert.sh
```

This script will:
- Extract the certificate chain from Panorama
- Save to `/etc/panovision/panorama-ca.crt`
- Restart the API proxy service

### SSL Certificate Setup

The installation creates a self-signed certificate. For production:

1. **Generate CSR:**
   ```bash
   sudo ./deploy/generate-apache-csr.sh
   ```

2. **Submit CSR** to your certificate authority

3. **Install certificate:**
   ```bash
   sudo ./deploy/install-apache-ssl-cert.sh
   ```

See [deploy/APACHE_SSL_CSR.md](deploy/APACHE_SSL_CSR.md) and [deploy/APACHE_SSL_INSTALL.md](deploy/APACHE_SSL_INSTALL.md) for detailed instructions.

### DNS Configuration

Ensure DNS is configured to point to your server:

```bash
# Verify DNS resolution
nslookup panovision.sncorp.com
# Should return your server IP
```

## SSL Certificate Options

### Option 1: Self-Signed (Default)

The installation script automatically creates a self-signed certificate. Users will see a browser security warning, which is expected.

**Location:**
- Certificate: `/etc/ssl/panovision/panovision-selfsigned.crt`
- Private Key: `/etc/ssl/panovision/panovision-selfsigned.key`

### Option 2: Let's Encrypt (Recommended for Production)

```bash
# Install certbot
dnf install -y certbot python3-certbot-apache

# Obtain certificate
certbot --apache -d panovision.sncorp.com

# Auto-renewal is set up automatically
```

### Option 3: Custom Certificate

Use the provided scripts:

```bash
# Generate CSR
sudo ./deploy/generate-apache-csr.sh

# After receiving certificate from CA
sudo ./deploy/install-apache-ssl-cert.sh
```

## Updating the Application

### Quick Update

```bash
cd /opt/Panovision
git pull
npm install
export NODE_OPTIONS="--openssl-legacy-provider"
npm run build
rsync -av --delete dist/ /var/www/panovision/
sudo systemctl reload httpd
```

### Full Reinstallation

If you need to reconfigure:

```bash
cd /opt/Panovision
sudo ./deploy/install.sh
```

The script will backup old configurations before replacing them.

## Troubleshooting

### Application Not Loading

**Check Apache status:**
```bash
systemctl status httpd
```

**Check error logs:**
```bash
tail -50 /var/log/httpd/panovision-error.log
```

**Verify files are deployed:**
```bash
ls -la /var/www/panovision/
```

**Test Apache configuration:**
```bash
httpd -t
```

### API Proxy Issues

**Check service status:**
```bash
systemctl status api-proxy
```

**View logs:**
```bash
journalctl -u api-proxy -n 50
```

**Check Panorama certificate:**
```bash
ls -la /etc/panovision/panorama-ca.crt
```

**If certificate errors, install Panorama cert:**
```bash
cd /opt/Panovision
sudo ./deploy/fetch-panorama-cert.sh
```

### Port Conflicts

**Check what's using ports 80/443:**
```bash
ss -tlnp | grep -E ':80|:443'
```

**Stop conflicting services:**
```bash
systemctl stop httpd
systemctl stop nginx
```

### SSL Certificate Errors

**For Panorama:**
```bash
cd /opt/Panovision
sudo ./deploy/fetch-panorama-cert.sh
```

**For web server:**
- Verify certificate files exist: `ls -la /etc/ssl/panovision/`
- Check Apache SSL configuration: `grep -i ssl /etc/httpd/conf.d/panovision.conf`
- Test SSL: `openssl s_client -connect localhost:443`

### SELinux Issues (if enabled)

```bash
# Check SELinux status
getenforce

# If enforcing, set proper context
chcon -R -t httpd_sys_content_t /var/www/panovision
setsebool -P httpd_can_network_connect 1
```

### Firewall Issues

```bash
# Check firewall status
firewall-cmd --list-all

# Add services if needed
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload
```

## Directory Structure

After installation:

```
/opt/Panovision/          # Source code
├── deploy/                   # Deployment scripts
├── dist/                     # Built application
└── .env                      # Environment configuration

/var/www/panovision/          # Deployed application files
├── index.html
└── assets/

/etc/httpd/conf.d/
└── panovision.conf           # Apache configuration

/etc/panovision/
├── api-key                   # Panorama API key (secure)
└── panorama-config           # Panorama URL configuration

/etc/ssl/panovision/
├── panovision-selfsigned.crt
└── panovision-selfsigned.key

/var/log/httpd/
├── panovision-access.log
└── panovision-error.log
```

## Service Management

### Apache

```bash
# Start
systemctl start httpd

# Stop
systemctl stop httpd

# Restart
systemctl restart httpd

# Reload (no downtime)
systemctl reload httpd

# Enable on boot
systemctl enable httpd

# Check status
systemctl status httpd
```

### API Proxy

```bash
# Start
systemctl start api-proxy

# Stop
systemctl stop api-proxy

# Restart
systemctl restart api-proxy

# Enable on boot
systemctl enable api-proxy

# Check status
systemctl status api-proxy

# View logs
journalctl -u api-proxy -f
```

## Security Best Practices

1. **Use HTTPS**: Always use SSL/TLS in production
2. **Keep Updated**: Regularly update system packages
3. **Firewall**: Only expose ports 80 and 443
4. **API Key**: Stored securely with restricted permissions
5. **OIDC**: Use tenant-specific authority for better security
6. **Backups**: Regularly backup configuration and data

## Support

For additional help:
- Check [deploy/README.md](deploy/README.md) for deployment-specific documentation
- Review [AZURE_OIDC_SETUP.md](AZURE_OIDC_SETUP.md) for OIDC configuration
- Check service logs for detailed error messages
