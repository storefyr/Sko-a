#!/bin/sh
# Skoðja update script - run on the Jolla Phone
# Usage: sh update.sh [version]
# Example: sh update.sh 0.9.3
# Or download and run directly:
#   curl -sL https://raw.githubusercontent.com/storefyr/Sko-a/main/harbour-skodja/update.sh | sh -s 0.9.3

set -e

VERSION="${1:-0.9.4}"
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

# Kill any existing python daemon processes (from manual runs)
echo "--- Cleaning up any existing daemon processes ---"
pkill -f "github_client.py" 2>/dev/null || true
sleep 1

# Clear any stale lock files
LOCK_FILE="${HOME}/.local/share/com.storefyr/harbour-skodja/state.lock"
if [ -f "${LOCK_FILE}" ]; then
    echo "Removing stale lock file..."
    rm -f "${LOCK_FILE}" 2>/dev/null || true
fi

echo "--- Starting service ---"
if systemctl --user start harbour-skodja.service; then
    echo "Service start command succeeded"
else
    echo "WARNING: systemctl start failed, trying again after delay..."
    sleep 3
    systemctl --user start harbour-skodja.service || echo "ERROR: Failed to start service"
fi

echo ""
echo "=== Checking status ==="
systemctl --user status harbour-skodja.service || true

echo ""
echo "=== Verifying daemon is running ==="
sleep 3
if systemctl --user is-active --quiet harbour-skodja.service; then
    echo "OK: Daemon is active (running)"
else
    echo ""
    echo "WARNING: Daemon is not running!"
    echo ""
    echo "--- Diagnostic information ---"
    echo "Service file location:"
    systemctl --user cat harbour-skodja.service 2>/dev/null || echo "(could not read service file)"
    echo ""
    echo "Python script exists:"
    ls -la /usr/share/harbour-skodja/python/gitwatch/github_client.py 2>/dev/null || echo "(script not found!)"
    echo ""
    echo "Data directory:"
    ls -la "${HOME}/.local/share/com.storefyr/harbour-skodja/" 2>/dev/null || echo "(directory not found)"
    echo ""
    echo "--- Attempting manual start for debugging ---"
    echo "Running: python3 /usr/share/harbour-skodja/python/gitwatch/github_client.py 5"
    timeout 10 python3 /usr/share/harbour-skodja/python/gitwatch/github_client.py 5 2>&1 || true
    echo ""
    echo "--- Recent journal logs ---"
    journalctl --user -u harbour-skodja.service --no-pager -n 30 2>/dev/null || echo "(no journal access)"
    echo ""
    echo "--- Try manually: ---"
    echo "  systemctl --user start harbour-skodja.service"
    echo "  journalctl --user -u harbour-skodja.service -f"
    echo "  python3 /usr/share/harbour-skodja/python/gitwatch/github_client.py 5"
fi

echo ""
echo "=== Recent logs ==="
journalctl --user -u harbour-skodja.service --no-pager -n 20 2>/dev/null || echo "(no journal access)"

echo ""
echo "=== Done! ==="
echo "Skoðja ${VERSION} installed."
echo "The daemon checks GitHub every 60 seconds and sends notifications."
echo "Open the app to see activity and change settings."
