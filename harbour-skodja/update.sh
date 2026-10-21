#!/bin/sh
# Skoðja update script - run on the Jolla Phone
# Usage: sh update.sh [version]
# Example: sh update.sh 0.6.3

set -e

VERSION="${1:-0.6.3}"
ARCH="aarch64"
RPM_NAME="harbour-skodja-${VERSION}-${ARCH}.rpm"
DOWNLOAD_URL="https://github.com/storefyr/Sko-a/releases/download/v${VERSION}/${RPM_NAME}"
TMP_DIR="/tmp"

echo "=== Skoðja Update Script ==="
echo "Version: ${VERSION}"
echo "Architecture: ${ARCH}"
echo ""

echo "--- Step 1: Stop old service ---"
systemctl --user stop harbour-skodja.service 2>/dev/null || echo "Service was not running (OK)"

echo "--- Step 2: Download new RPM ---"
cd "${TMP_DIR}"
curl -LO "${DOWNLOAD_URL}"
echo "Downloaded: ${RPM_NAME}"

echo "--- Step 3: Install new version ---"
pkcon install-local "${TMP_DIR}/${RPM_NAME}"

echo "--- Step 4: Reload systemd ---"
systemctl --user daemon-reload

echo "--- Step 5: Start service ---"
systemctl --user start harbour-skodja.service

echo ""
echo "=== Checking status ==="
systemctl --user status harbour-skodja.service

echo ""
echo "=== Recent logs ==="
journalctl --user -u harbour-skodja.service --no-pager -n 10 || true

echo ""
echo "=== Done! ==="
echo "If the service shows 'active (running)', everything is working."
