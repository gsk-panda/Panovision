# Using JFrog Repository for Node.js Installation

When NodeSource is blocked by your corporate proxy, you can configure the installation script to use a JFrog repository file to install Node.js.

## Quick Setup

### Option 1: Environment Variable (Recommended)

Set the `JFROG_REPO_URL` environment variable before running the installation script:

```bash
export JFROG_REPO_URL="https://jfrog.devworks.sncorp.com/artifactory/devworks-misc/repofiles/rhel/rocky9.repo"

cd /opt/Panovision
./deploy/install.sh
```

When prompted for Node.js installation method, it will automatically use JFrog.

### Option 2: Interactive Prompt

When running the installation script, choose option 1 when prompted for Node.js installation method, then provide:
- JFrog Repository URL (defaults to: `https://jfrog.devworks.sncorp.com/artifactory/devworks-misc/repofiles/rhel/rocky9.repo`)

## How It Works

The installation script will:

1. Download the `.repo` file from the JFrog URL
2. Place it in `/etc/yum.repos.d/`
3. Refresh the DNF cache
4. Install Node.js and npm using `dnf install`

## Repository File Format

The repository file should be a standard YUM repository file (`.repo` format) containing:

```ini
[repository-name]
name=Repository Description
baseurl=https://jfrog.devworks.sncorp.com/artifactory/path/to/repo
enabled=1
gpgcheck=0
```

## Troubleshooting

### Error: Failed to download metadata for repo 'nodesource-nodejs'

If you see this error during installation, it means NodeSource repositories are still enabled. Fix it by:

**Quick Fix:**
```bash
# Disable NodeSource repositories
sudo chmod +x deploy/fix-nodesource-repo.sh
sudo ./deploy/fix-nodesource-repo.sh

# Then continue with installation
```

**Manual Fix:**
```bash
# Disable all NodeSource repositories
sudo sed -i 's/^enabled=1/enabled=0/' /etc/yum.repos.d/nodesource*.repo

# Or remove them entirely
sudo rm -f /etc/yum.repos.d/nodesource*.repo

# Update with NodeSource disabled
sudo dnf update -y --disablerepo=nodesource*
```

### Error: Could not download repository file from JFrog

1. **Verify the URL is accessible:**
   ```bash
   curl -I https://jfrog.devworks.sncorp.com/artifactory/devworks-misc/repofiles/rhel/rocky9.repo
   ```

2. **Check if authentication is required:**
   ```bash
   curl -u username:password https://jfrog.devworks.sncorp.com/artifactory/devworks-misc/repofiles/rhel/rocky9.repo
   ```

3. **Verify network connectivity:**
   ```bash
   ping jfrog.devworks.sncorp.com
   ```

### Error: Failed to install Node.js from JFrog repository

1. **Check the repository file was downloaded correctly:**
   ```bash
   cat /etc/yum.repos.d/rocky9.repo
   ```

2. **Verify the repository is accessible:**
   ```bash
   dnf repoinfo --all | grep -i nodejs
   ```

3. **Test repository access:**
   ```bash
   dnf search nodejs
   ```

4. **Check if Node.js packages are available:**
   ```bash
   dnf list available | grep nodejs
   ```

### Authentication Required

If JFrog requires authentication, you can:

**Option 1: Use .netrc file**
```bash
cat > ~/.netrc <<EOF
machine jfrog.devworks.sncorp.com
login your-username
password your-password
EOF
chmod 600 ~/.netrc
```

**Option 2: Modify the repository file after download**

The script downloads the repo file to `/etc/yum.repos.d/`. If authentication is needed, you can edit it:

```bash
nano /etc/yum.repos.d/rocky9.repo
```

Add authentication to the baseurl:
```ini
baseurl=https://username:password@jfrog.devworks.sncorp.com/artifactory/path/to/repo
```

**Option 3: Use JFrog API Key**

If your JFrog instance supports API keys, you can modify the baseurl in the repository file to include the API key.

## Manual Installation Alternative

If JFrog setup is problematic, you can manually install Node.js:

### Step 1: Download Repository File Manually

```bash
curl -o /etc/yum.repos.d/rocky9.repo \
  https://jfrog.devworks.sncorp.com/artifactory/devworks-misc/repofiles/rhel/rocky9.repo
```

### Step 2: Install Node.js

```bash
dnf makecache
dnf install -y nodejs npm
```

### Step 3: Verify Installation

```bash
node -v  # Should show v20.x.x or v18.x.x
npm -v
```

### Step 4: Continue with Installation Script

After Node.js is installed, you can continue with the installation script:

```bash
cd /opt/Panovision
# Choose option 2 (NodeSource) - the script will detect Node.js is already installed
./deploy/install.sh
```

## Example: Complete JFrog Setup

```bash
# Set environment variable
export JFROG_REPO_URL="https://jfrog.devworks.sncorp.com/artifactory/devworks-misc/repofiles/rhel/rocky9.repo"

# Run installation
cd /opt/Panovision
./deploy/install.sh

# When prompted for Node.js method, it will use JFrog automatically
```

## Repository File Location

After installation, the repository file will be located at:
```
/etc/yum.repos.d/rocky9.repo
```

You can view or modify it as needed:
```bash
cat /etc/yum.repos.d/rocky9.repo
```

## Alternative: Configure NodeSource via Proxy

If you prefer to use NodeSource but need to configure proxy:

```bash
export http_proxy="http://proxy.example.com:8080"
export https_proxy="http://proxy.example.com:8080"
export no_proxy="localhost,127.0.0.1"

./deploy/install.sh
# Choose option 2 (NodeSource)
```
