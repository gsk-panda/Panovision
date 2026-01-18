#!/bin/bash

set -e

if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    exit 1
fi

echo "Disabling NodeSource repositories..."

NODESOURCE_DISABLED=false

for repo_file in /etc/yum.repos.d/nodesource*.repo; do
    if [ -f "$repo_file" ]; then
        echo "Disabling: $(basename $repo_file)"
        sed -i 's/^enabled=1/enabled=0/' "$repo_file" 2>/dev/null || true
        NODESOURCE_DISABLED=true
    fi
done

if [ "$NODESOURCE_DISABLED" = false ]; then
    echo "No NodeSource repositories found"
else
    echo "✓ NodeSource repositories disabled"
    echo ""
    echo "You can now continue with the installation script"
    echo "Or run: dnf update -y --disablerepo=nodesource*"
fi
