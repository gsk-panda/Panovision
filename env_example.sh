################################################################################
# New-Panovision Environment Configuration
################################################################################

################################################################################
# GEMINI API CONFIGURATION (Required)
################################################################################
# Your Google Gemini API key
# Get it from: https://ai.google.dev/
GEMINI_API_KEY=your_gemini_api_key_here

################################################################################
# APPLICATION CONFIGURATION
################################################################################
# Port the application will run on
PORT=3000

# Node environment (development, production)
NODE_ENV=production

# Application URL (used for OIDC redirects)
APP_URL=http://localhost:3000

################################################################################
# OIDC AUTHENTICATION CONFIGURATION
################################################################################
# Enable or disable OIDC authentication
# Set to 'true' to enable OIDC, 'false' to disable
# When disabled, the application will run without authentication
ENABLE_OIDC=false

################################################################################
# OIDC PROVIDER SETTINGS (Required when ENABLE_OIDC=true)
################################################################################

# OIDC Issuer URL (Identity Provider)
# Examples:
#   - Keycloak: https://keycloak.example.com/realms/your-realm
#   - Okta: https://your-domain.okta.com
#   - Azure AD: https://login.microsoftonline.com/{tenant-id}/v2.0
#   - Auth0: https://your-domain.auth0.com
OIDC_ISSUER_URL=https://your-oidc-provider.com

# OAuth2/OIDC Client ID (from your identity provider)
OIDC_CLIENT_ID=your_client_id

# OAuth2/OIDC Client Secret (from your identity provider)
OIDC_CLIENT_SECRET=your_client_secret

# Callback URL after authentication
# Must be registered in your identity provider
# Format: {APP_URL}/auth/callback
OIDC_REDIRECT_URI=http://localhost:3000/auth/callback

# Post logout redirect URL
# Where to redirect after logout
OIDC_POST_LOGOUT_REDIRECT_URI=http://localhost:3000

# OIDC Scopes (space-separated)
# Common scopes: openid profile email
# Additional scopes depend on your provider
OIDC_SCOPE=openid profile email

# OIDC Response Type
# Usually 'code' for authorization code flow
OIDC_RESPONSE_TYPE=code

# OIDC Response Mode
# Usually 'query' or 'form_post'
OIDC_RESPONSE_MODE=query

################################################################################
# SESSION CONFIGURATION (Required when ENABLE_OIDC=true)
################################################################################
# Secret key for session encryption
# Generate a strong random string (e.g., openssl rand -base64 32)
SESSION_SECRET=change_this_to_a_random_string_at_least_32_characters_long

# Session cookie name
SESSION_NAME=panovision_session

# Session max age in milliseconds (default: 24 hours)
SESSION_MAX_AGE=86400000

# Session cookie secure flag (set to true for HTTPS)
SESSION_SECURE=false

# Session cookie HttpOnly flag
SESSION_HTTP_ONLY=true

# Session cookie SameSite policy (Strict, Lax, None)
SESSION_SAME_SITE=Lax

################################################################################
# ADVANCED OIDC OPTIONS (Optional)
################################################################################

# OIDC Discovery endpoint (usually auto-configured from ISSUER_URL)
# OIDC_DISCOVERY_URL=https://your-oidc-provider.com/.well-known/openid-configuration

# Custom authorization endpoint (if not using discovery)
# OIDC_AUTHORIZATION_ENDPOINT=https://your-oidc-provider.com/oauth2/authorize

# Custom token endpoint (if not using discovery)
# OIDC_TOKEN_ENDPOINT=https://your-oidc-provider.com/oauth2/token

# Custom userinfo endpoint (if not using discovery)
# OIDC_USERINFO_ENDPOINT=https://your-oidc-provider.com/oauth2/userinfo

# Custom logout endpoint (if not using discovery)
# OIDC_END_SESSION_ENDPOINT=https://your-oidc-provider.com/oauth2/logout

# PKCE (Proof Key for Code Exchange) - recommended for public clients
# OIDC_USE_PKCE=true

# Clock tolerance for token validation (in seconds)
# OIDC_CLOCK_TOLERANCE=60

################################################################################
# LOGGING CONFIGURATION (Optional)
################################################################################
# Log level (error, warn, info, debug)
LOG_LEVEL=info

# Enable access logs
ENABLE_ACCESS_LOG=true

################################################################################
# SECURITY CONFIGURATION (Optional)
################################################################################
# CORS allowed origins (comma-separated)
# CORS_ORIGINS=http://localhost:3000,https://yourdomain.com

# Rate limiting
# RATE_LIMIT_WINDOW_MS=900000
# RATE_LIMIT_MAX_REQUESTS=100

################################################################################
# PROVIDER-SPECIFIC EXAMPLES
################################################################################

# === KEYCLOAK EXAMPLE ===
# OIDC_ISSUER_URL=https://keycloak.example.com/realms/myrealm
# OIDC_CLIENT_ID=panovision-client
# OIDC_CLIENT_SECRET=your-keycloak-client-secret
# OIDC_REDIRECT_URI=http://localhost:3000/auth/callback
# OIDC_SCOPE=openid profile email roles

# === OKTA EXAMPLE ===
# OIDC_ISSUER_URL=https://your-domain.okta.com
# OIDC_CLIENT_ID=0oa1a2b3c4d5e6f7g8h9
# OIDC_CLIENT_SECRET=your-okta-client-secret
# OIDC_REDIRECT_URI=http://localhost:3000/auth/callback
# OIDC_SCOPE=openid profile email

# === AZURE AD EXAMPLE ===
# OIDC_ISSUER_URL=https://login.microsoftonline.com/your-tenant-id/v2.0
# OIDC_CLIENT_ID=your-azure-application-id
# OIDC_CLIENT_SECRET=your-azure-client-secret
# OIDC_REDIRECT_URI=http://localhost:3000/auth/callback
# OIDC_SCOPE=openid profile email

# === AUTH0 EXAMPLE ===
# OIDC_ISSUER_URL=https://your-domain.auth0.com
# OIDC_CLIENT_ID=your-auth0-client-id
# OIDC_CLIENT_SECRET=your-auth0-client-secret
# OIDC_REDIRECT_URI=http://localhost:3000/auth/callback
# OIDC_SCOPE=openid profile email

# === GOOGLE EXAMPLE ===
# OIDC_ISSUER_URL=https://accounts.google.com
# OIDC_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
# OIDC_CLIENT_SECRET=your-google-client-secret
# OIDC_REDIRECT_URI=http://localhost:3000/auth/callback
# OIDC_SCOPE=openid profile email
