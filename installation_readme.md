# New-Panovision Installation Guide for RHEL 9

This guide provides instructions for installing New-Panovision on Red Hat Enterprise Linux 9 with optional OIDC authentication.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Installation](#quick-installation)
- [Manual Installation](#manual-installation)
- [OIDC Configuration](#oidc-configuration)
- [Post-Installation](#post-installation)
- [Troubleshooting](#troubleshooting)
- [Uninstallation](#uninstallation)

## Prerequisites

- RHEL 9 server with root or sudo access
- Minimum 2GB RAM
- Minimum 10GB free disk space
- Internet connectivity for downloading packages
- A Gemini API key (get it from https://ai.google.dev/)

## Quick Installation

1. Download the installation script:
```bash
curl -O https://raw.githubusercontent.com/gsk-panda/New-Panovision/main/install-panovision-rhel9.sh
chmod +x install-panovision-rhel9.sh
```

2. Run the installation script:
```bash
sudo ./install-panovision-rhel9.sh
```

3. Configure your environment:
```bash
sudo nano /opt/panovision/app/.env
```

4. Add your Gemini API key and other settings, then restart:
```bash
sudo systemctl restart panovision
```

## Manual Installation

If you prefer to install manually or want to understand each step:

### 1. Install System Dependencies

```bash
# Enable EPEL repository
sudo dnf install -y epel-release

# Update system
sudo dnf update -y

# Install required packages
sudo dnf install -y git nginx firewalld policycoreutils-python-utils openssl

# Install Node.js 20
sudo dnf module reset -y nodejs
sudo dnf module enable -y nodejs:20
sudo dnf install -y nodejs npm
```

### 2. Create Application User

```bash
sudo useradd -r -m -d /opt/panovision -s /bin/bash panovision
```

### 3. Clone Repository

```bash
sudo -u panovision git clone https://github.com/gsk-panda/New-Panovision.git /opt/panovision/app
```

### 4. Configure Environment

```bash
sudo cp /opt/panovision/app/.env.example /opt/panovision/app/.env
sudo chown panovision:panovision /opt/panovision/app/.env
sudo chmod 600 /opt/panovision/app/.env
sudo nano /opt/panovision/app/.env
```

### 5. Install Dependencies and Build

```bash
cd /opt/panovision/app
sudo -u panovision npm install
sudo -u panovision npm run build
```

### 6. Create Systemd Service

Create `/etc/systemd/system/panovision.service`:

```ini
[Unit]
Description=New-Panovision Application
After=network.target

[Service]
Type=simple
User=panovision
WorkingDirectory=/opt/panovision/app
Environment=NODE_ENV=production
EnvironmentFile=/opt/panovision/app/.env
ExecStart=/usr/bin/npm run preview
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=panovision

[Install]
WantedBy=multi-user.target
```

Enable and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable panovision
sudo systemctl start panovision
```

### 7. Configure Nginx

Create `/etc/nginx/conf.d/panovision.conf`:

```nginx
server {
    listen 80;
    server_name _;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

Test and reload Nginx:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

### 8. Configure Firewall

```bash
sudo systemctl start firewalld
sudo systemctl enable firewalld
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

### 9. Configure SELinux

```bash
sudo setsebool -P httpd_can_network_connect 1
sudo semanage port -a -t http_port_t -p tcp 3000
```

## OIDC Configuration

To enable OIDC authentication:

### 1. Set OIDC Environment Variables

Edit `/opt/panovision/app/.env`:

```bash
# Enable OIDC
ENABLE_OIDC=true

# Configure your OIDC provider
OIDC_ISSUER_URL=https://your-oidc-provider.com
OIDC_CLIENT_ID=your_client_id
OIDC_CLIENT_SECRET=your_client_secret
OIDC_REDIRECT_URI=http://your-domain.com/auth/callback
OIDC_SCOPE=openid profile email

# Generate a secure session secret
SESSION_SECRET=$(openssl rand -base64 32)
```

### 2. Provider-Specific Examples

#### Keycloak

```bash
OIDC_ISSUER_URL=https://keycloak.example.com/realms/myrealm
OIDC_CLIENT_ID=panovision-client
OIDC_CLIENT_SECRET=your-keycloak-client-secret
```

#### Okta

```bash
OIDC_ISSUER_URL=https://your-domain.okta.com
OIDC_CLIENT_ID=0oa1a2b3c4d5e6f7g8h9
OIDC_CLIENT_SECRET=your-okta-client-secret
```

#### Azure AD

```bash
OIDC_ISSUER_URL=https://login.microsoftonline.com/your-tenant-id/v2.0
OIDC_CLIENT_ID=your-azure-application-id
OIDC_CLIENT_SECRET=your-azure-client-secret
```

#### Auth0

```bash
OIDC_ISSUER_URL=https://your-domain.auth0.com
OIDC_CLIENT_ID=your-auth0-client-id
OIDC_CLIENT_SECRET=your-auth0-client-secret
```

### 3. Register Callback URL

Register the following callback URL in your OIDC provider:
```
http://your-domain.com/auth/callback
```

### 4. Restart Service

```bash
sudo systemctl restart panovision
```

## Post-Installation

### Verify Installation

Check service status:
```bash
sudo systemctl status panovision
```

View logs:
```bash
sudo journalctl -u panovision -f
```

Test the application:
```bash
curl http://localhost:3000
```

### SSL/HTTPS Setup (Recommended)

Install Certbot for Let's Encrypt:

```bash
sudo dnf install -y certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

Update your `.env` file:
```bash
APP_URL=https://your-domain.com
OIDC_REDIRECT_URI=https://your-domain.com/auth/callback
SESSION_SECURE=true
```

### Monitoring

Check application logs:
```bash
# Real-time logs
sudo journalctl -u panovision -f

# Last 100 lines
sudo journalctl -u panovision -n 100

# Logs from last hour
sudo journalctl -u panovision --since "1 hour ago"
```

Check Nginx logs:
```bash
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### Updating the Application

```bash
cd /opt/panovision/app
sudo -u panovision git pull
sudo -u panovision npm install
sudo -u panovision npm run build
sudo systemctl restart panovision
```

## Troubleshooting

### Service Won't Start

Check the logs:
```bash
sudo journalctl -u panovision -n 50
```

Verify configuration:
```bash
sudo -u panovision cat /opt/panovision/app/.env
```

### Port Already in Use

Check what's using port 3000:
```bash
sudo ss -tulpn | grep 3000
```

Change the port in `.env`:
```bash
PORT=3001
```

### Nginx 502 Bad Gateway

Verify the application is running:
```bash
sudo systemctl status panovision
curl http://localhost:3000
```

Check SELinux is configured correctly:
```bash
sudo getsebool httpd_can_network_connect
```

### OIDC Authentication Issues

Verify OIDC configuration:
```bash
curl ${OIDC_ISSUER_URL}/.well-known/openid-configuration
```

Check callback URL is registered correctly in your provider.

Ensure `SESSION_SECRET` is set and secure.

### Permission Denied Errors

Fix ownership:
```bash
sudo chown -R panovision:panovision /opt/panovision/app
sudo chmod 600 /opt/panovision/app/.env
```

### Can't Access from External Network

Check firewall:
```bash
sudo firewall-cmd --list-all
```

Verify SELinux:
```bash
sudo ausearch -m avc -ts recent
```

## Uninstallation

To completely remove New-Panovision:

```bash
curl -O https://raw.githubusercontent.com/gsk-panda/New-Panovision/main/uninstall-panovision-rhel9.sh
chmod +x uninstall-panovision-rhel9.sh
sudo ./uninstall-panovision-rhel9.sh
```

## Security Best Practices

1. **Keep the system updated:**
   ```bash
   sudo dnf update -y
   ```

2. **Use strong secrets:**
   ```bash
   openssl rand -base64 32
   ```

3. **Enable HTTPS:** Use Let's Encrypt or your own certificates

4. **Restrict access:** Use firewall rules to limit access

5. **Regular backups:**
   ```bash
   sudo tar -czf panovision-backup-$(date +%Y%m%d).tar.gz /opt/panovision/app/.env
   ```

6. **Monitor logs:** Regularly check application and system logs

7. **Update dependencies:** Keep Node.js packages up to date

## Support

For issues and questions:
- GitHub Issues: https://github.com/gsk-panda/New-Panovision/issues
- Check logs: `sudo journalctl -u panovision -f`

## License

Refer to the repository license file for licensing information.
