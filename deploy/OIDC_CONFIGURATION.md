# OIDC Configuration Guide

## Where to Input OIDC Information

OIDC (Azure AD) configuration is input during the installation process when you run the installation script.

## During Installation

When you run `deploy/install-new.sh`, the script will prompt you for:

1. **Server URL or IP** - Your server hostname or IP address
2. **Panorama IP or URL** - Your Panorama server URL
3. **Panorama API Key** - Your Panorama API key
4. **Azure OIDC Configuration** (if OIDC is enabled):
   - **Azure Client ID** (`VITE_AZURE_CLIENT_ID`)
   - **Azure Authority** (e.g., `https://login.microsoftonline.com/tenant-id`)
   - **Azure Redirect URI** (defaults to `https://your-server-url`)

## Example Installation Flow

```bash
cd /opt/Panovision
sudo ./deploy/install-new.sh
```

The script will prompt:
```
Server URL or IP (e.g., panovision.sncorp.com or 10.100.5.227): panovision.sncorp.com
Panorama IP or URL (e.g., panorama.example.com or 10.1.0.100): https://10.1.0.100
Panorama API Key: [your-api-key]

Azure OIDC Configuration (required for OIDC authentication):
Leave blank to disable OIDC and allow anonymous access

Azure Client ID (VITE_AZURE_CLIENT_ID): 12345678-1234-1234-1234-123456789012
Azure Authority (e.g., https://login.microsoftonline.com/tenant-id): https://login.microsoftonline.com/your-tenant-id
Azure Redirect URI (default: https://panovision.sncorp.com): [press Enter for default]
```

## Disabling OIDC

If you want to disable OIDC (allow anonymous access), you can:

1. **During installation**: Leave the Azure Client ID and Authority fields blank when prompted
2. **Command line**: Run with `--disable-oidc` flag:
   ```bash
   sudo ./deploy/install-new.sh --disable-oidc
   ```
3. **Environment variable**: Set before running:
   ```bash
   export VITE_OIDC_ENABLED=false
   sudo ./deploy/install-new.sh
   ```

## Getting Azure OIDC Information

To get your Azure OIDC credentials:

1. **Go to Azure Portal**: https://portal.azure.com
2. **Navigate to**: Azure Active Directory > App registrations
3. **Find or create** your app registration
4. **Get Client ID**: From the Overview page, copy the "Application (client) ID"
5. **Get Tenant ID**: From the Overview page, copy the "Directory (tenant) ID"
6. **Build Authority URL**: `https://login.microsoftonline.com/{tenant-id}`

For detailed setup instructions, see: `AZURE_OIDC_SETUP.md`

## After Installation

The OIDC configuration is stored in:
- **Environment file**: `/opt/Panovision/.env`
- **Build-time variables**: Embedded in the built application

To change OIDC settings after installation:

1. Edit `/opt/Panovision/.env`
2. Rebuild the application:
   ```bash
   cd /opt/Panovision
   export NODE_OPTIONS="--openssl-legacy-provider"
   npm run build
   ```
3. Redeploy:
   ```bash
   rsync -av --delete /opt/Panovision/dist/ /var/www/panovision/
   ```

## Environment Variables

The following environment variables are used:

- `VITE_OIDC_ENABLED` - Enable/disable OIDC (true/false)
- `VITE_AZURE_CLIENT_ID` - Azure AD Application (client) ID
- `VITE_AZURE_AUTHORITY` - Azure AD authority URL
- `VITE_AZURE_REDIRECT_URI` - Redirect URI after authentication

These are set during installation and embedded in the build.
