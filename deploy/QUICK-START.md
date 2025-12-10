# Quick Start - Remote Deployment

## Option 1: Transfer and Run (Recommended)

1. **On your local machine, create a deployment archive:**
   ```bash
   cd /path/to/New-Panovision
   tar -czf panovision-deploy.tar.gz . --exclude='node_modules' --exclude='.git' --exclude='dist'
   ```

2. **Transfer to the server:**
   ```bash
   scp panovision-deploy.tar.gz root@panovision.officeours.com:/opt/
   ```

3. **SSH into the server:**
   ```bash
   ssh root@panovision.officeours.com
   ```

4. **Extract and run:**
   ```bash
   cd /opt
   tar -xzf panovision-deploy.tar.gz -C panovision
   cd panovision
   chmod +x deploy/deploy-package.sh
   ./deploy/deploy-package.sh
   ```

## Option 2: Git Clone (If using Git)

1. **SSH into the server:**
   ```bash
   ssh root@panovision.officeours.com
   ```

2. **Clone and deploy:**
   ```bash
   cd /opt
   git clone <your-repo-url> panovision
   cd panovision
   chmod +x deploy/deploy-package.sh
   ./deploy/deploy-package.sh
   ```

## Option 3: Copy-Paste Single Command

If you have the files already on the server, you can run:

```bash
cd /path/to/New-Panovision && chmod +x deploy/deploy-package.sh && ./deploy/deploy-package.sh
```

## Post-Installation

The deployment script automatically creates a self-signed SSL certificate. The site will be accessible at `https://panovision.officeours.com`, but browsers will show a security warning for the self-signed certificate. This is expected behavior.

## Troubleshooting

If something goes wrong:

```bash
# Check Nginx status
systemctl status nginx

# View error logs
tail -50 /var/log/nginx/panovision-error.log
journalctl -u nginx -n 50

# Test Nginx config
nginx -t

# Check if files are deployed
ls -la /var/www/panovision/
```

