# Azure OIDC SSO Setup Guide

This guide explains how to configure Azure Active Directory (Azure AD) OIDC authentication for PanoVision.

## Prerequisites

- Azure AD tenant
- Azure AD App Registration permissions
- Application deployed and accessible via HTTPS

## Step 1: Create Azure AD App Registration

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Azure Active Directory** > **App registrations**
3. Click **New registration**
4. Configure:
   - **Name**: PanoVision
   - **Supported account types**: Choose based on your needs (Single tenant, Multi-tenant, etc.)
   - **Redirect URI**: 
     - Type: **Single-page application (SPA)**
     - URI: `https://panovision.example.com` (replace with your actual server URL)
5. Click **Register**

## Step 2: Configure App Registration

1. **Note the Application (client) ID** - you'll need this for `VITE_AZURE_CLIENT_ID`

2. **Configure API permissions**:
   - Go to **API permissions**
   - Click **Add a permission** > **Microsoft Graph** > **Delegated permissions**
   - Add: `User.Read`
   - Click **Add permissions**

3. **Configure Authentication**:
   - Go to **Authentication**
   - Under **Single-page application**, ensure your redirect URI is listed
   - Under **Implicit grant and hybrid flows**, check **ID tokens** (if needed)
   - Click **Save**

4. **Get Tenant ID**:
   - Go to **Overview**
   - Copy the **Directory (tenant) ID** - you'll need this for `VITE_AZURE_AUTHORITY`

## Step 3: Configure Environment Variables

Create a `.env` file in the project root (or copy from `.env.example`):

```env
VITE_AZURE_CLIENT_ID=your-client-id-here
VITE_AZURE_AUTHORITY=https://login.microsoftonline.com/your-tenant-id
VITE_AZURE_REDIRECT_URI=https://panovision.example.com

# OIDC Feature Toggle
# Set to 'true' or '1' to enable OIDC authentication
# When disabled, the app will allow anonymous access
# Default: disabled (false)
VITE_OIDC_ENABLED=false
```

**To enable OIDC authentication**, set:
```env
VITE_OIDC_ENABLED=true
VITE_AZURE_CLIENT_ID=your-client-id-here
VITE_AZURE_AUTHORITY=https://login.microsoftonline.com/your-tenant-id
VITE_AZURE_REDIRECT_URI=https://panovision.example.com
```

**For production deployment**, set these as environment variables on your server or use a build-time configuration.

## Step 4: Update Deployment Scripts

The environment variables need to be available at build time. Update your build process:

**Option 1: Environment file (recommended for development)**
```bash
# Create .env file before building
cp .env.example .env
# Edit .env with your values
npm run build
```

**Option 2: Build-time environment variables**
```bash
VITE_AZURE_CLIENT_ID=xxx VITE_AZURE_AUTHORITY=xxx npm run build
```

**Option 3: For production deployment, update deploy scripts to include .env file**

## Step 5: Deploy and Test

1. Build the application with environment variables set
2. Deploy to your server
3. Test the login flow:
   - Click "Sign in with Azure AD"
   - You should be redirected to Microsoft login
   - After authentication, you'll be redirected back to the app
   - Your user information should be displayed

## Troubleshooting

### "Invalid client" error
- Verify `VITE_AZURE_CLIENT_ID` is correct
- Check the App Registration exists in Azure Portal

### Redirect URI mismatch
- Ensure the redirect URI in Azure AD matches exactly: `https://panovision.example.com` (replace with your actual server URL)
- Check for trailing slashes or protocol mismatches

### "AADSTS50011" error
- The redirect URI in your app doesn't match what's configured in Azure AD
- Update the redirect URI in Azure AD App Registration

### Token acquisition fails
- Verify API permissions are granted and admin consent is provided (if required)
- Check that `User.Read` permission is added

## Security Considerations

1. **Never commit `.env` files** to version control
2. **Use environment variables** in production
3. **Restrict app registration** to specific users/groups if needed
4. **Enable Conditional Access** policies in Azure AD for additional security
5. **Use tenant-specific authority** instead of `/common` for better security

## Advanced Configuration

### Single Tenant vs Multi-Tenant

- **Single Tenant**: `https://login.microsoftonline.com/{tenant-id}`
- **Multi-Tenant**: `https://login.microsoftonline.com/common`
- **Organizations only**: `https://login.microsoftonline.com/organizations`

### Additional Scopes

If you need additional Microsoft Graph permissions, update `loginRequest.scopes` in `services/authConfig.ts`:

```typescript
export const loginRequest: PopupRequest = {
  scopes: ['User.Read', 'Mail.Read'], // Add additional scopes
};
```

### Redirect vs Popup Flow

The current implementation uses popup flow. To use redirect flow:

1. Update `authService.ts` to use `loginRedirect()` instead of `loginPopup()`
2. Handle the redirect callback in `App.tsx` using `handleRedirectPromise()`

