#!/bin/sh
# Skoðja update script - run on the Jolla Phone
# Usage: sh update.sh [version]
# Example: sh update.sh 0.9.5
# Or download and run directly:
#   curl -sL https://raw.githubusercontent.com/storefyr/Sko-a/main/harbour-skodja/update.sh | sh -s 0.9.5

set -e

VERSION="${1:-0.9.5}"
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
rm -f "${RPM_NAME}"
curl -LO "${DOWNLOAD_URL}"
echo "Downloaded: ${RPM_NAME}"
ls -la "${RPM_NAME}"

echo "--- Step 3: Verify RPM ---"
if ! rpm -qp "${RPM_NAME}" 2>/dev/null; then
    echo "ERROR: Downloaded file is not a valid RPM!"
    echo "File info:"
    file "${RPM_NAME}" 2>/dev/null || head -c 200 "${RPM_NAME}"
    exit 1
fi

echo "--- Step 4: Install new version ---"
pkcon install-local "${TMP_DIR}/${RPM_NAME}"

echo "--- Step 5: Reload systemd ---"
systemctl --user daemon-reload

echo "--- Step 6: Restart lipstick (for notification categories) ---"
systemctl --user restart lipstick || true

echo "--- Step 7: Enable service ---"
systemctl --user enable harbour-skodja.service 2>/dev/null || true

echo "--- Step 8: Clean up any existing daemon processes ---"
pkill -f "github_client.py" 2>/dev/null || true
pkill -f "daemon-wrapper.sh" 2>/dev/null || true
sleep 1

echo "--- Step 9: Clear any stale lock files ---"
LOCK_FILE="${HOME}/.local/share/com.storefyr/harbour-skodja/state.lock"
if [ -f "${LOCK_FILE}" ]; then
    echo "Removing stale lock file: ${LOCK_FILE}"
    rm -f "${LOCK_FILE}" 2>/dev/null || true
fi

echo "--- Step 10: Show service file ---"
echo "Service file contents:"
systemctl --user cat harbour-skodja.service 2>/dev/null || echo "(could not read service file)"
echo ""

echo "--- Step 11: Start service ---"
if systemctl --user start harbour-skodja.service; then
    echo "Service start command succeeded"
else
    echo "WARNING: systemctl start failed, trying again after delay..."
    sleep 3
    systemctl --user start harbour-skodja.service || echo "ERROR: Failed to start service"
fi

echo ""
echo "=== Checking status ==="
sleep 2
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
    echo ""
    echo "1. Service status (detailed):"
    systemctl --user status harbour-skodja.service --no-pager -l 2>/dev/null || true
    echo ""
    echo "2. Service file location and contents:"
    ls -la /usr/lib/systemd/user/harbour-skodja.service 2>/dev/null || echo "(not found in /usr/lib/systemd/user/)"
    ls -la /usr/lib/systemd/user/harbour-skodja.service 2>/dev/null && cat /usr/lib/systemd/user/harbour-skodja.service
    echo ""
    echo "3. Python script exists:"
    ls -la /usr/share/harbour-skodja/python/gitwatch/github_client.py 2>/dev/null || echo "(script not found!)"
    echo ""
    echo "4. Wrapper script exists:"
    ls -la /usr/share/harbour-skodja/daemon-wrapper.sh 2>/dev/null || echo "(wrapper not found)"
    echo ""
    echo "5. Data directory:"
    ls -la "${HOME}/.local/share/com.storefyr/harbour-skodja/" 2>/dev/null || echo "(directory not found)"
    echo ""
    echo "6. Environment check (what systemd sees):"
    systemctl --user show harbour-skodja.service -p Environment 2>/dev/null || true
    echo ""
    echo "--- Attempting manual start for debugging ---"
    echo "Running wrapper script manually:"
    timeout 15 /usr/share/harbour-skodja/daemon-wrapper.sh 5 2>&1 || true
    echo ""
    echo "--- Recent journal logs (last 50 lines) ---"
    journalctl --user -u harbour-skodja.service --no-pager -n 50 2>/dev/null || echo "(no journal access)"
    echo ""
    echo "--- Wrapper logs ---"
    journalctl --user -t harbour-skodja-wrapper --no-pager -n 20 2>/dev/null || echo "(no wrapper logs)"
    echo ""
    echo "--- Try manually: ---"
    echo "  systemctl --user start harbour-skodja.service"
    echo "  journalctl --user -u harbour-skodja.service -f"
    echo "  journalctl -t harbour-skodja-wrapper -f"
    echo "  /usr/share/harbour-skodja/daemon-wrapper.sh 5"
fi

echo ""
echo "=== Recent logs (last 30 lines) ==="
journalctl --user -u harbour-skodja.service --no-pager -n 30 2>/dev/null || echo "(no journal access)"

echo ""
echo "=== Done! ==="
echo "Skoðja ${VERSION} installed."
echo "The daemon checks GitHub every 60 seconds and sends notifications."
echo "Open the app to see activity and change settings."
