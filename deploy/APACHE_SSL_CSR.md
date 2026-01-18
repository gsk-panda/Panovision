# Apache SSL Certificate CSR Generation Guide

This guide explains how to generate a Certificate Signing Request (CSR) for an Apache SSL certificate on RHEL.

## Quick Start

```bash
cd /opt/Panovision
chmod +x deploy/generate-apache-csr.sh
sudo ./deploy/generate-apache-csr.sh
```

## What is a CSR?

A Certificate Signing Request (CSR) is a file that contains:
- Your public key
- Information about your organization and server
- A signature created with your private key

You submit the CSR to a Certificate Authority (CA) to get a signed SSL certificate.

## CSR Generation Process

1. **Private Key Generation**: Creates a secure private key (2048 or 4096 bits)
2. **CSR Generation**: Creates a CSR file using the private key
3. **CSR Submission**: Send the CSR to your CA
4. **Certificate Installation**: Install the certificate received from the CA

## Using the Script

The script will prompt you for:

- **Common Name (CN)**: Your domain name or IP address (e.g., `panovision.sncorp.com` or `10.100.5.227`)
- **Organization (O)**: Your company or organization name
- **Organizational Unit (OU)**: Department or division (e.g., IT Department)
- **City/Locality (L)**: City where your organization is located
- **State/Province (ST)**: State or province
- **Country Code (C)**: Two-letter country code (e.g., US, CA, GB)
- **Email Address**: Optional contact email
- **Key Size**: 2048 or 4096 bits (2048 is recommended for most cases)

## Files Generated

- **Private Key**: `/etc/ssl/panovision/panovision.key`
  - Keep this secure and never share it
  - File permissions: 600 (root only)
  
- **CSR File**: `/etc/ssl/panovision/panovision.csr`
  - This is safe to share with your CA
  - File permissions: 644

## Manual CSR Generation

If you prefer to generate the CSR manually:

### Step 1: Generate Private Key

```bash
sudo mkdir -p /etc/ssl/panovision
sudo openssl genrsa -out /etc/ssl/panovision/panovision.key 2048
sudo chmod 600 /etc/ssl/panovision/panovision.key
```

### Step 2: Generate CSR

```bash
sudo openssl req -new -key /etc/ssl/panovision/panovision.key \
    -out /etc/ssl/panovision/panovision.csr \
    -subj "/C=US/ST=State/L=City/O=Organization/OU=IT/CN=panovision.sncorp.com"
```

### Step 3: View CSR

```bash
cat /etc/ssl/panovision/panovision.csr
```

Or view details:

```bash
openssl req -in /etc/ssl/panovision/panovision.csr -noout -text
```

## Submitting CSR to Certificate Authority

### Internal CA

If you have an internal CA:

1. Copy the CSR file to your CA server
2. Submit it through your CA's web interface or command-line tools
3. Download the signed certificate

### Let's Encrypt

For Let's Encrypt, use Certbot instead of manual CSR:

```bash
sudo dnf install -y certbot python3-certbot-apache
sudo certbot --apache -d panovision.sncorp.com
```

### Commercial CA

1. Copy the CSR contents:
   ```bash
   cat /etc/ssl/panovision/panovision.csr
   ```
2. Paste it into the CA's web form
3. Complete the validation process
4. Download the certificate files

## Installing the Certificate

Once you receive the certificate from your CA:

### Step 1: Save the Certificate

```bash
sudo nano /etc/ssl/panovision/panovision.crt
# Paste the certificate content
sudo chmod 644 /etc/ssl/panovision/panovision.crt
```

### Step 2: Save Intermediate Certificates (if provided)

```bash
sudo nano /etc/ssl/panovision/panovision-chain.crt
# Paste the intermediate certificate(s)
sudo chmod 644 /etc/ssl/panovision/panovision-chain.crt
```

### Step 3: Update Apache Configuration

Edit `/etc/httpd/conf.d/panovision.conf`:

```apache
<VirtualHost *:443>
    # ... other configuration ...
    
    SSLCertificateFile /etc/ssl/panovision/panovision.crt
    SSLCertificateKeyFile /etc/ssl/panovision/panovision.key
    
    # If you have intermediate certificates:
    SSLCertificateChainFile /etc/ssl/panovision/panovision-chain.crt
</VirtualHost>
```

### Step 4: Test and Restart Apache

```bash
sudo httpd -t
sudo systemctl restart httpd
```

## Verifying the Certificate

After installation, verify the certificate:

```bash
# View certificate details
openssl x509 -in /etc/ssl/panovision/panovision.crt -noout -text

# Check certificate expiration
openssl x509 -in /etc/ssl/panovision/panovision.crt -noout -dates

# Test SSL connection
openssl s_client -connect panovision.sncorp.com:443 -showcerts
```

## Common Issues

### CSR Already Exists

If you need to regenerate the CSR:

```bash
# Backup existing files
sudo cp /etc/ssl/panovision/panovision.key /etc/ssl/panovision/panovision.key.backup
sudo cp /etc/ssl/panovision/panovision.csr /etc/ssl/panovision/panovision.csr.backup

# Regenerate (this will overwrite existing files)
sudo ./deploy/generate-apache-csr.sh
```

### Wrong Information in CSR

If you made a mistake, regenerate the CSR with the correct information. The private key can be reused.

### Certificate Installation Fails

- Verify certificate file format (should start with `-----BEGIN CERTIFICATE-----`)
- Check file permissions (644 for certificate, 600 for key)
- Ensure Apache can read the files (check SELinux if enabled)
- Verify the certificate matches the private key:
  ```bash
  openssl x509 -noout -modulus -in /etc/ssl/panovision/panovision.crt | openssl md5
  openssl rsa -noout -modulus -in /etc/ssl/panovision/panovision.key | openssl md5
  ```
  Both commands should output the same MD5 hash.

## Security Best Practices

1. **Protect the Private Key**
   - Never share the private key
   - Keep file permissions at 600 (root only)
   - Consider encrypting the key with a passphrase for additional security

2. **Secure Storage**
   - Store backups of the private key in a secure location
   - Use proper access controls

3. **Certificate Renewal**
   - Set reminders for certificate expiration
   - Renew certificates before they expire
   - Keep track of certificate expiration dates

4. **Key Rotation**
   - Consider rotating keys periodically
   - Generate new keys when renewing certificates

## Example: Complete Workflow

```bash
# 1. Generate CSR
cd /opt/Panovision
sudo ./deploy/generate-apache-csr.sh

# 2. Submit CSR to CA (copy contents)
cat /etc/ssl/panovision/panovision.csr

# 3. After receiving certificate, save it
sudo nano /etc/ssl/panovision/panovision.crt
# Paste certificate, save, and exit

# 4. Update Apache config (if needed)
sudo nano /etc/httpd/conf.d/panovision.conf

# 5. Test and restart
sudo httpd -t
sudo systemctl restart httpd

# 6. Verify
curl -vI https://panovision.sncorp.com
```
