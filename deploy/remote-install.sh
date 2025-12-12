#!/bin/bash

set -e

echo "=========================================="
echo "PanoVision Remote Installation Helper"
echo "=========================================="
echo ""
echo "This script helps you prepare files for remote deployment."
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ARCHIVE_NAME="panovision-deploy-$(date +%Y%m%d-%H%M%S).tar.gz"

echo "Creating deployment archive..."
cd "$PROJECT_DIR"

tar -czf "$ARCHIVE_NAME" \
    --exclude='node_modules' \
    --exclude='.git' \
    --exclude='dist' \
    --exclude='*.log' \
    --exclude='.DS_Store' \
    --exclude='*.swp' \
    --exclude='*.swo' \
    .

echo ""
echo "Archive created: $ARCHIVE_NAME"
echo ""
echo "Next steps:"
echo "1. Transfer to server:"
echo "   scp $ARCHIVE_NAME root@<your-server-ip-or-hostname>:/opt/"
echo ""
echo "2. SSH into server:"
echo "   ssh root@<your-server-ip-or-hostname>"
echo ""
echo "3. Extract and deploy:"
echo "   cd /opt"
echo "   tar -xzf $ARCHIVE_NAME -C panovision"
echo "   cd panovision"
echo "   chmod +x deploy/deploy-package.sh"
echo "   ./deploy/deploy-package.sh"
echo ""

