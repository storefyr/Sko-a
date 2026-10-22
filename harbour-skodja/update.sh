#!/bin/sh
# Skoðja update script - run on the Jolla Phone
# Usage: sh update.sh [version]
# Example: sh update.sh 0.9.3
# Or download and run directly:
#   curl -sL https://raw.githubusercontent.com/storefyr/Sko-a/main/harbour-skodja/update.sh | sh -s 0.9.3

set -e

VERSION="${1:-0.9.3}"
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

echo "--- Step 5: Restart lipstick (for notification categories) ---"
systemctl --user restart lipstick || true

echo "--- Step 6: Enable and start service ---"
systemctl --user enable harbour-skodja.service 2>/dev/null || true
systemctl --user start harbour-skodja.service || echo "WARNING: Failed to start service"

echo ""
echo "=== Checking status ==="
systemctl --user status harbour-skodja.service || true

echo ""
echo "=== Verifying daemon is running ==="
sleep 2
if systemctl --user is-active --quiet harbour-skodja.service; then
    echo "OK: Daemon is active (running)"
else
    echo "WARNING: Daemon is not running!"
    echo "Try manually: systemctl --user start harbour-skodja.service"
    echo "Check logs:   journalctl --user -u harbour-skodja.service -n 20"
fi

echo ""
echo "=== Recent logs ==="
journalctl --user -u harbour-skodja.service --no-pager -n 10 2>/dev/null || echo "(no journal access)"

echo ""
echo "=== Done! ==="
echo "Skoðja ${VERSION} installed."
echo "The daemon checks GitHub every 60 seconds and sends notifications."
echo "Open the app to see activity and change settings."
