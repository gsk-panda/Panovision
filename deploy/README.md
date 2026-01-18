# PanoVision Deployment Documentation

This directory contains deployment scripts, configuration files, and utilities for PanoVision.

## Contents

### Installation Scripts

- **`install.sh`** - Main installation script. Handles complete deployment including:
  - System preparation and package updates
  - Node.js installation (JFrog or NodeSource)
  - Apache HTTP Server setup
  - Application build and deployment
  - API proxy service configuration
  - SSL certificate generation
  - Firewall configuration

### Configuration Files

- **`apache-panovision.conf`** - Apache virtual host configuration
  - HTTP to HTTPS redirect
  - HTTPS virtual host with SSL
  - SPA routing support
  - API proxy configuration
  - Security headers
  - Compression and caching

- **`api-proxy.service`** - Systemd service file for API proxy
  - Runs as `panovision` user
  - Auto-starts on boot
  - Restarts on failure

- **`api-proxy.js`** - Node.js API proxy service
  - Proxies requests to Panorama API
  - Handles TLS certificate verification
  - Loads API key from secure location

### Utility Scripts

#### SSL Certificate Management

- **`generate-apache-csr.sh`** - Generate Certificate Signing Request for Apache
  - Creates private key
  - Generates CSR with proper subject
  - Provides instructions for certificate authority

- **`install-apache-ssl-cert.sh`** - Install SSL certificate and private key
  - Copies certificate files
  - Updates Apache configuration
  - Restarts Apache

#### Panorama Certificate Management

- **`fetch-panorama-cert.sh`** - Fetch Panorama SSL certificate
  - Extracts certificate chain from Panorama server
  - Saves to `/etc/panovision/panorama-ca.crt`
  - Restarts API proxy service

#### TLS Verification

- **`enable-tls-verification.sh`** - Enable TLS certificate verification for Panorama
- **`disable-tls-verification.sh`** - Disable TLS verification (testing only)

#### Troubleshooting Scripts

- **`diagnose-api-proxy.sh`** - Comprehensive API proxy diagnostics
  - Checks user permissions
  - Verifies file permissions and ownership
  - Tests Node.js execution
  - Validates service configuration

- **`fix-api-proxy-permissions.sh`** - Fix API proxy file permissions
  - Sets correct ownership (panovision:panovision)
  - Sets proper file permissions
  - Configures SELinux context

- **`force-fix-api-proxy.sh`** - Aggressive API proxy permission fix
  - More comprehensive permission fixes
  - SELinux context configuration
  - Service restart

- **`test-api-proxy-access.sh`** - Test API proxy connectivity
  - Tests local API proxy endpoint
  - Verifies Panorama connectivity
  - Checks certificate validation

- **`troubleshoot-services.sh`** - Comprehensive service troubleshooting
  - Checks Apache and API proxy status
  - Verifies port listening
  - Checks firewall rules
  - Validates SSL certificates
  - Tests local connectivity

#### System Configuration

- **`fix-nodesource-repo.sh`** - Disable NodeSource repositories
  - Useful when using JFrog repository
  - Prevents proxy conflicts

- **`fix-openssl-conflict.sh`** - Resolve OpenSSL FIPS provider conflicts
  - Handles package conflicts during updates
  - Uses `--allowerasing` flag

### Documentation Files

- **`APACHE_SSL_CSR.md`** - Guide for generating Apache SSL certificate CSR
- **`APACHE_SSL_INSTALL.md`** - Guide for installing Apache SSL certificates
- **`JFROG_SETUP.md`** - Guide for using JFrog repository for Node.js installation
- **`OIDC_CONFIGURATION.md`** - Guide for configuring OIDC authentication

## Quick Reference

### Installation

```bash
cd /opt/Panovision
sudo chmod +x deploy/install.sh
sudo ./deploy/install.sh
```

### SSL Certificate Setup

```bash
# Generate CSR
sudo ./deploy/generate-apache-csr.sh

# Install certificate
sudo ./deploy/install-apache-ssl-cert.sh
```

### Panorama Certificate

```bash
# Fetch Panorama certificate
sudo ./deploy/fetch-panorama-cert.sh
```

### Troubleshooting

```bash
# Diagnose API proxy
sudo ./deploy/diagnose-api-proxy.sh

# Fix API proxy permissions
sudo ./deploy/fix-api-proxy-permissions.sh

# Comprehensive troubleshooting
sudo ./deploy/troubleshoot-services.sh
```

## Installation Script Details

### What the Installation Script Does

1. **System Preparation**
   - Updates system packages
   - Resolves OpenSSL conflicts
   - Cleans DNF cache
   - Disables conflicting repositories

2. **Node.js Installation**
   - Option 1: JFrog repository (recommended for proxy environments)
   - Option 2: NodeSource (requires internet access)
   - Verifies Node.js 18+ installation

3. **Apache Installation**
   - Installs `httpd` and `mod_ssl`
   - Enables required modules (proxy, rewrite, deflate, headers)
   - Configures virtual hosts

4. **Application Setup**
   - Creates `panovision` user
   - Creates application directory
   - Stores API key securely
   - Installs Node.js dependencies
   - Builds application with environment variables

5. **Deployment**
   - Copies built files to `/var/www/panovision`
   - Sets proper ownership and permissions
   - Configures Apache virtual hosts

6. **Service Configuration**
   - Sets up API proxy systemd service
   - Configures file permissions and SELinux context
   - Starts and enables services

7. **SSL Setup**
   - Creates self-signed certificate (if needed)
   - Configures Apache SSL virtual host

8. **Firewall Configuration**
   - Opens HTTP and HTTPS ports
   - Reloads firewall rules

### Installation Script Options

```bash
# Disable OIDC (allow anonymous access)
sudo ./deploy/install.sh --disable-oidc

# Enable OIDC (default)
sudo ./deploy/install.sh --enable-oidc

# Set environment variable
export VITE_OIDC_ENABLED=false
sudo ./deploy/install.sh

# Use JFrog repository
export JFROG_REPO_URL="https://jfrog.example.com/repo.repo"
sudo ./deploy/install.sh
```

## Apache Configuration

### Virtual Hosts

The Apache configuration includes:

1. **HTTP Virtual Host** (port 80)
   - Redirects all traffic to HTTPS

2. **HTTPS Virtual Host** (port 443)
   - Serves application files
   - Handles SPA routing
   - Proxies API requests to API proxy service
   - Configures SSL/TLS
   - Sets security headers
   - Enables compression

### SPA Routing

The configuration includes rewrite rules to support React Router:

```apache
RewriteEngine On
RewriteBase /
RewriteRule ^index\.html$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.html [L]
```

### API Proxy Configuration

API requests to `/api/panorama/*` are proxied to the local API proxy service:

```apache
<Location /api/panorama>
    RewriteEngine On
    RewriteRule ^/api/panorama(.*)$ /api$1 [P]
    ProxyPass http://127.0.0.1:3001/api
    ProxyPassReverse http://127.0.0.1:3001/api
</Location>
```

## API Proxy Service

### Configuration

The API proxy service:
- Runs on `http://127.0.0.1:3001`
- Loads API key from `/etc/panovision/api-key`
- Loads Panorama URL from `/etc/panovision/panorama-config`
- Verifies TLS certificates (if configured)

### Service Management

```bash
# Start
systemctl start api-proxy

# Stop
systemctl stop api-proxy

# Restart
systemctl restart api-proxy

# Status
systemctl status api-proxy

# View logs
journalctl -u api-proxy -f
```

### Environment Variables

The service supports:
- `PANORAMA_VERIFY_SSL`: Enable/disable TLS verification (default: true)
- `PANORAMA_CA_FILE`: Path to custom CA certificate file

## Troubleshooting Guide

### API Proxy Not Starting

1. **Check service status:**
   ```bash
   systemctl status api-proxy
   ```

2. **View error logs:**
   ```bash
   journalctl -u api-proxy -n 50
   ```

3. **Check file permissions:**
   ```bash
   ls -la /opt/Panovision/deploy/api-proxy.js
   # Should be owned by panovision:panovision
   ```

4. **Run diagnostics:**
   ```bash
   sudo ./deploy/diagnose-api-proxy.sh
   ```

5. **Fix permissions:**
   ```bash
   sudo ./deploy/fix-api-proxy-permissions.sh
   ```

### Apache Not Starting

1. **Check Apache status:**
   ```bash
   systemctl status httpd
   ```

2. **Test configuration:**
   ```bash
   httpd -t
   ```

3. **Check error logs:**
   ```bash
   tail -50 /var/log/httpd/panovision-error.log
   ```

4. **Check port conflicts:**
   ```bash
   ss -tlnp | grep -E ':80|:443'
   ```

### SSL Certificate Issues

1. **For web server:**
   - Verify certificate files exist: `ls -la /etc/ssl/panovision/`
   - Check Apache config: `grep -i ssl /etc/httpd/conf.d/panovision.conf`
   - Test SSL: `openssl s_client -connect localhost:443`

2. **For Panorama:**
   - Install Panorama certificate: `sudo ./deploy/fetch-panorama-cert.sh`
   - Check certificate file: `ls -la /etc/panovision/panorama-ca.crt`
   - View API proxy logs for certificate errors

### Port Conflicts

1. **Identify conflicting service:**
   ```bash
   ss -tlnp | grep -E ':80|:443'
   ```

2. **Stop conflicting service:**
   ```bash
   systemctl stop <service-name>
   ```

3. **Disable service (if needed):**
   ```bash
   systemctl disable <service-name>
   ```

## Security Considerations

1. **File Permissions**
   - API key: 640, root:panovision
   - Application files: 755, panovision:panovision
   - SSL certificates: 600 (key), 644 (cert)

2. **SELinux**
   - API proxy script: `bin_t` context
   - Web root: `httpd_sys_content_t` context
   - Network connections: `httpd_can_network_connect` boolean

3. **Firewall**
   - Only ports 80 and 443 should be publicly accessible
   - API proxy (port 3001) should only be accessible from localhost

4. **TLS Verification**
   - Always enable TLS verification in production
   - Install Panorama CA certificate for proper verification

## Maintenance

### Regular Tasks

1. **Monitor logs:**
   ```bash
   tail -f /var/log/httpd/panovision-error.log
   journalctl -u api-proxy -f
   ```

2. **Update application:**
   ```bash
   cd /opt/Panovision
   git pull
   npm install
   export NODE_OPTIONS="--openssl-legacy-provider"
   npm run build
   rsync -av --delete dist/ /var/www/panovision/
   systemctl reload httpd
   ```

3. **Backup configuration:**
   ```bash
   tar -czf panovision-backup-$(date +%Y%m%d).tar.gz \
     /etc/httpd/conf.d/panovision.conf \
     /etc/panovision/ \
     /etc/ssl/panovision/
   ```

## Additional Resources

- [Main README](../README.md) - Project overview
- [Installation Guide](../INSTALLATION_GUIDE.md) - Detailed installation instructions
- [OIDC Configuration Guide](OIDC_CONFIGURATION.md) - OIDC setup
- [Apache SSL CSR Guide](APACHE_SSL_CSR.md) - SSL certificate generation
- [Apache SSL Install Guide](APACHE_SSL_INSTALL.md) - SSL certificate installation
- [JFrog Setup Guide](JFROG_SETUP.md) - JFrog repository configuration