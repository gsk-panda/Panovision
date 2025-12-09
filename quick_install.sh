#!/bin/bash

################################################################################
# New-Panovision Quick Installer
# Downloads and runs the latest installer directly from GitHub
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

GITHUB_RAW_URL="https://raw.githubusercontent.com/gsk-panda/New-Panovision/main"
INSTALLER_SCRIPT="install-panovision-rhel9.sh"
TEMP_DIR="/tmp/panovision_installer_$$"

# Function to print colored messages
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Cleanup function
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run this script as root or with sudo"
    exit 1
fi

print_header "New-Panovision Quick Installer"
echo ""
print_message "This script will download and run the latest installer from GitHub"
print_message "Repository: https://github.com/gsk-panda/New-Panovision"
echo ""

# Check for required commands
print_message "Checking prerequisites..."

if ! command -v curl &> /dev/null; then
    print_warning "curl not found. Installing..."
    dnf install -y curl
fi

if ! command -v git &> /dev/null; then
    print_warning "git not found. It will be installed during setup..."
fi

# Create temporary directory
print_message "Creating temporary directory..."
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Download the installer script
print_message "Downloading installer from GitHub..."
if curl -fsSL "${GITHUB_RAW_URL}/${INSTALLER_SCRIPT}" -o "${INSTALLER_SCRIPT}"; then
    print_message "Installer downloaded successfully"
else
    print_error "Failed to download installer from GitHub"
    print_error "URL: ${GITHUB_RAW_URL}/${INSTALLER_SCRIPT}"
    print_error "Please check:"
    print_error "  1. The file exists in your GitHub repository"
    print_error "  2. Your internet connection is working"
    print_error "  3. GitHub is accessible from this machine"
    exit 1
fi

# Make the installer executable
chmod +x "${INSTALLER_SCRIPT}"

# Show what will be executed
print_message "About to run: ${INSTALLER_SCRIPT}"
echo ""
read -p "Continue with installation? (yes/no): " -r
echo

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_message "Installation cancelled."
    exit 0
fi

# Run the installer
print_header "Running Installer"
echo ""
bash "${INSTALLER_SCRIPT}"

# Installation complete
echo ""
print_header "Installation Complete"
print_message "The installer has finished running."
print_message "Check the output above for any additional configuration steps."
echo ""
