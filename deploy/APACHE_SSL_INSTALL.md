# Installing SSL Certificate for Apache

## Quick Installation

If you have your SSL certificate (.crt) and private key (.key) files:

```bash
cd /opt/Panovision
chmod +x deploy/install-apache-ssl-cert.sh
sudo ./deploy/install-apache-ssl-cert.sh
```

The script will:
1. Prompt for your certificate and key file paths
2. Ask if you have an intermediate/chain certificate
3. Copy files to `/etc/ssl/panovision/`
4. Verify the certificate and key
5. Update Apache configuration
6. Restart Apache

## Manual Installation

### Step 1: Copy Certificate Files

```bash
# Create SSL directory if it doesn't exist
sudo mkdir -p /etc/ssl/panovision

# Copy your certificate
sudo cp /path/to/your/certificate.crt /etc/ssl/panovision/panovision.crt
sudo chmod 644 /etc/ssl/panovision/panovision.crt
sudo chown root:root /etc/ssl/panovision/panovision.crt

# Copy your private key
sudo cp /path/to/your/private.key /etc/ssl/panovision/panovision.key
sudo chmod 600 /etc/ssl/panovision/panovision.key
sudo chown root:root /etc/ssl/panovision/panovision.key

# If you have an intermediate/chain certificate
sudo cp /path/to/your/chain.crt /etc/ssl/panovision/panovision-chain.crt
sudo chmod 644 /etc/ssl/panovision/panovision-chain.crt
sudo chown root:root /etc/ssl/panovision/panovision-chain.crt
```

### Step 2: Update Apache Configuration

Edit `/etc/httpd/conf.d/panovision.conf` and update the SSL certificate paths:

```apache
<VirtualHost *:443>
    # ... other configuration ...
    
    SSLEngine on
    SSLCertificateFile /etc/ssl/panovision/panovision.crt
    SSLCertificateKeyFile /etc/ssl/panovision/panovision.key
    
    # If you have an intermediate/chain certificate:
    SSLCertificateChainFile /etc/ssl/panovision/panovision-chain.crt
</VirtualHost>
```

### Step 3: Test and Restart Apache

```bash
# Test configuration
sudo httpd -t

# If test passes, restart Apache
sudo systemctl restart httpd

# Verify Apache is running
sudo systemctl status httpd
```

## File Locations

- **Certificate**: `/etc/ssl/panovision/panovision.crt`
- **Private Key**: `/etc/ssl/panovision/panovision.key`
- **Chain Certificate** (if applicable): `/etc/ssl/panovision/panovision-chain.crt`
- **Apache Config**: `/etc/httpd/conf.d/panovision.conf`

## Verifying the Certificate

### Check Certificate Details

```bash
openssl x509 -in /etc/ssl/panovision/panovision.crt -noout -text
```

### Check Certificate Expiration

```bash
openssl x509 -in /etc/ssl/panovision/panovision.crt -noout -dates
```

### Verify Certificate and Key Match

```bash
openssl x509 -noout -modulus -in /etc/ssl/panovision/panovision.crt | openssl md5
openssl rsa -noout -modulus -in /etc/ssl/panovision/panovision.key | openssl md5
```

Both commands should output the same MD5 hash.

### Test SSL Connection

```bash
openssl s_client -connect panovision.sncorp.com:443 -showcerts
```

## Common Issues

### Certificate and Key Don't Match

If you get an error that the certificate and key don't match:
- Verify you're using the correct key file for the certificate
- Check that the certificate and key are from the same CSR

### Apache Won't Start

1. Check Apache error log:
   ```bash
   sudo tail -f /var/log/httpd/panovision-error.log
   ```

2. Test Apache configuration:
   ```bash
   sudo httpd -t
   ```

3. Check file permissions:
   ```bash
   ls -la /etc/ssl/panovision/
   ```
   Certificate should be 644, key should be 600

### Certificate Chain Issues

If browsers show certificate warnings:
- Ensure you have the intermediate/chain certificate installed
- Add `SSLCertificateChainFile` directive in Apache config
- Verify the chain certificate is valid:
  ```bash
  openssl x509 -in /etc/ssl/panovision/panovision-chain.crt -noout -text
  ```

## Security Best Practices

1. **Protect the Private Key**
   - Keep file permissions at 600 (read/write for root only)
   - Never share the private key
   - Store backups securely

2. **Certificate Expiration**
   - Set reminders for certificate renewal
   - Renew certificates before they expire
   - Check expiration: `openssl x509 -in /etc/ssl/panovision/panovision.crt -noout -dates`

3. **Backup**
   - Keep backups of certificates and keys
   - Store backups in a secure location
   - Document where backups are stored

## Replacing Self-Signed Certificate

If you're replacing the self-signed certificate that was created during installation:

1. The self-signed certificate is at:
   - `/etc/ssl/panovision/panovision-selfsigned.crt`
   - `/etc/ssl/panovision/panovision-selfsigned.key`

2. These will be automatically replaced when you install your new certificate using the script.

3. The script backs up existing certificates before replacing them.
