#!/bin/bash

set -e

if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    exit 1
fi

echo "Fixing OpenSSL FIPS provider conflict..."

echo "Cleaning DNF cache and refreshing metadata..."
dnf clean all
dnf makecache

echo "Detected conflict: openssl-fips-provider-so (old) vs openssl-fips-provider (new)"
echo "Removing old package explicitly before upgrade..."

if rpm -q openssl-fips-provider-so >/dev/null 2>&1; then
    echo "Attempting to remove old openssl-fips-provider-so package..."
    
    dnf remove -y openssl-fips-provider-so --setopt=clean_requirements_on_remove=false 2>/dev/null || {
        echo "Direct removal failed (it's a systemd dependency), trying with systemd upgrade..."
        
        echo "Upgrading systemd first to break dependency..."
        dnf upgrade -y systemd systemd-libs systemd-udev --allowerasing --best 2>/dev/null || {
            echo "Systemd upgrade failed, trying to remove with nodeps..."
            rpm -e --nodeps openssl-fips-provider-so 2>/dev/null || {
                echo "Nodeps removal failed, will try upgrade with replacement..."
            }
        }
    }
fi

echo ""
echo "Upgrading all OpenSSL packages to latest versions..."
dnf upgrade -y openssl* --allowerasing --best 2>/dev/null || {
    echo "Trying with best available packages..."
    dnf upgrade -y openssl* --allowerasing --nobest 2>/dev/null || {
        echo "Attempting to upgrade systemd and OpenSSL together..."
        dnf upgrade -y systemd openssl* --allowerasing --best 2>/dev/null || {
            echo "Trying alternative approach - upgrade all packages..."
            dnf upgrade -y --allowerasing --best 2>/dev/null || {
                echo "Warning: Some conflicts may persist"
            }
        }
    }
}

echo ""
echo "Updating all system packages to latest versions..."
dnf update -y --allowerasing --best 2>/dev/null || {
    echo "Update with --best failed, trying without it..."
    dnf update -y --allowerasing 2>/dev/null || dnf update -y
}

echo ""
echo "Verifying packages are up to date..."
dnf check-update >/dev/null 2>&1 && {
    echo "✓ All packages are up to date"
} || {
    echo "Some packages may still have updates available"
}

echo ""
echo "✓ OpenSSL conflict handling completed"
echo ""
echo "You can now continue with the installation script"
