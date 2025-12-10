# PanoVision Deployment Guide for RHEL 9.7

This guide provides instructions for deploying PanoVision on a RHEL 9.7 system using Nginx.

## Prerequisites

- RHEL 9.7 system with root/sudo access
- DNS record configured for `panovision.officeours.com` pointing to the server IP
- Ports 80 and 443 open in firewall
- Node.js 18+ and npm (will be installed by script)

## Quick Installation

1. **Transfer the application files to the server:**
   ```bash
   scp -r /path/to/New-Panovision root@your-server-ip:/opt/
   ```

2. **SSH into the server:**
   ```bash
   ssh root@your-server-ip
   ```

3. **Run the installation script:**
   ```bash
   cd /opt/New-Panovision
   chmod +x deploy/install.sh
   ./deploy/install.sh
   ```

The installation script will:
- Install Node.js, npm, and Nginx
- Create the application user and directory
- Build the application
- Configure Nginx
- Set up firewall rules
- Start the services

## SSL Certificate Setup

### Option 1: Let's Encrypt (Recommended)

After DNS is configured and the server is accessible:

```bash
certbot --nginx -d panovision.officeours.com
```

This will automatically:
- Obtain a free SSL certificate
- Configure Nginx to use it
- Set up automatic renewal

### Option 2: Self-Signed Certificate (Development Only)

The installation script creates a self-signed certificate if Let's Encrypt is not available. This is only suitable for testing and will show browser warnings.

## Manual Installation Steps

If you prefer to install manually:

1. **Install dependencies:**
   ```bash
   dnf install -y nodejs npm nginx firewalld
   ```

2. **Create application user:**
   ```bash
   useradd -r -s /bin/false -d /var/www/panovision panovision
   ```

3. **Build the application:**
   ```bash
   cd /opt/New-Panovision
   npm install
   npm run build
   ```

4. **Deploy files:**
   ```bash
   mkdir -p /var/www/panovision
   cp -r dist/* /var/www/panovision/
   chown -R panovision:panovision /var/www/panovision
   ```

5. **Configure Nginx:**
   ```bash
   cp deploy/nginx-panovision.conf /etc/nginx/conf.d/panovision.conf
   nginx -t
   systemctl enable nginx
   systemctl restart nginx
   ```

6. **Configure firewall:**
   ```bash
   firewall-cmd --permanent --add-service=http
   firewall-cmd --permanent --add-service=https
   firewall-cmd --reload
   ```

## Updating the Application

To update the application after making changes:

```bash
cd /opt/New-Panovision
chmod +x deploy/update.sh
./deploy/update.sh
```

Or manually:
```bash
cd /opt/New-Panovision
npm install
npm run build
rsync -av --delete dist/ /var/www/panovision/
systemctl reload nginx
```

## Directory Structure

```
/var/www/panovision/          # Application root
├── index.html                # Main HTML file
├── assets/                   # Built JavaScript and CSS
└── ...

/etc/nginx/conf.d/
└── panovision.conf           # Nginx configuration

/var/log/nginx/
├── panovision-access.log     # Access logs
└── panovision-error.log      # Error logs
```

## Troubleshooting

### Check Nginx Status
```bash
systemctl status nginx
```

### View Error Logs
```bash
tail -f /var/log/nginx/panovision-error.log
```

### Test Nginx Configuration
```bash
nginx -t
```

### Check Application Files
```bash
ls -la /var/www/panovision/
```

### Verify Ports are Open
```bash
ss -tlnp | grep -E ':(80|443)'
```

### Check Firewall Rules
```bash
firewall-cmd --list-all
```

## Security Considerations

1. **SSL/TLS**: Always use HTTPS in production. The Nginx config enforces HTTPS redirects.

2. **Firewall**: The installation script configures basic firewall rules. Review and adjust as needed.

3. **File Permissions**: Application files are owned by the `panovision` user with restricted permissions.

4. **Updates**: Keep the system and Nginx updated:
   ```bash
   dnf update -y
   ```

## Maintenance

### Regular Tasks

1. **Monitor logs:**
   ```bash
   tail -f /var/log/nginx/panovision-error.log
   ```

2. **Check SSL certificate expiration:**
   ```bash
   certbot certificates
   ```

3. **Renew SSL certificates (automatic, but can be done manually):**
   ```bash
   certbot renew
   ```

4. **Backup application files:**
   ```bash
   tar -czf panovision-backup-$(date +%Y%m%d).tar.gz /var/www/panovision
   ```

## Support

For issues or questions:
- Check Nginx error logs: `/var/log/nginx/panovision-error.log`
- Verify DNS resolution: `nslookup panovision.officeours.com`
- Test connectivity: `curl -I https://panovision.officeours.com`

