#!/bin/sh
# Skoðja update script - run on the Jolla Phone
# Usage: sh update.sh [version]
# Example: sh update.sh 0.9.7
# Or download and run directly:
#   curl -sL https://raw.githubusercontent.com/storefyr/Sko-a/main/harbour-skodja/update.sh | sh -s 0.9.7
#
# This script handles all installation methods automatically:
# 1. Try pkcon install-local (works without password on some setups)
# 2. Try zypper install (if available)
# 3. Copy RPM to Downloads folder and show instructions for GUI install

VERSION="${1:-0.9.7}"
ARCH="aarch64"
RPM_NAME="harbour-skodja-${VERSION}-${ARCH}.rpm"
DOWNLOAD_URL="https://github.com/storefyr/Sko-a/releases/download/v${VERSION}/${RPM_NAME}"
TMP_DIR="/tmp"
DOWNLOADS_DIR="${HOME}/Downloads"

echo "=== Skoðja Update Script v${VERSION} ==="
echo ""

# Check if running on Sailfish OS
if [ ! -f /etc/os-release ] || ! grep -q "sailfish\|Sailfish" /etc/os-release 2>/dev/null; then
    echo "WARNING: This does not appear to be Sailfish OS"
    echo "Continuing anyway..."
    echo ""
fi

echo "--- Step 1: Stop old service ---"
systemctl --user stop harbour-skodja.service 2>/dev/null && echo "Service stopped" || echo "Service was not running (OK)"

echo "--- Step 2: Download new RPM ---"
cd "${TMP_DIR}"
rm -f "${RPM_NAME}"
if curl -sLO "${DOWNLOAD_URL}"; then
    echo "Downloaded: ${RPM_NAME}"
    ls -la "${RPM_NAME}"
else
    echo "ERROR: Failed to download RPM"
    exit 1
fi

echo "--- Step 3: Verify RPM ---"
if rpm -qp "${RPM_NAME}" >/dev/null 2>&1; then
    echo "RPM verified: $(rpm -qp "${RPM_NAME}" 2>/dev/null)"
else
    echo "ERROR: Downloaded file is not a valid RPM!"
    exit 1
fi

echo ""
echo "--- Step 4: Install new version ---"

INSTALLED=0

# Method 1: Try pkcon install-local (may work without password on some setups)
echo "Trying method 1: pkcon install-local (user)"
if pkcon install-local "${TMP_DIR}/${RPM_NAME}" 2>/dev/null; then
    echo "SUCCESS: Installed via pkcon (user)"
    INSTALLED=1
fi

# Method 2: Try pkcon with --allow-reinstall (some setups need this)
if [ "${INSTALLED}" = "0" ]; then
    echo "Trying method 2: pkcon install-local --allow-reinstall"
    if pkcon install-local --allow-reinstall "${TMP_DIR}/${RPM_NAME}" 2>/dev/null; then
        echo "SUCCESS: Installed via pkcon --allow-reinstall"
        INSTALLED=1
    fi
fi

# Method 3: Try zypper (if available)
if [ "${INSTALLED}" = "0" ]; then
    if command -v zypper >/dev/null 2>&1; then
        echo "Trying method 3: zypper install"
        if zypper --non-interactive install "${TMP_DIR}/${RPM_NAME}" 2>/dev/null; then
            echo "SUCCESS: Installed via zypper"
            INSTALLED=1
        fi
    fi
fi

# Method 4: Try rpm -Uvh directly (may work on some systems)
if [ "${INSTALLED}" = "0" ]; then
    echo "Trying method 4: rpm -Uvh (direct)"
    if rpm -Uvh --force "${TMP_DIR}/${RPM_NAME}" 2>/dev/null; then
        echo "SUCCESS: Installed via rpm -Uvh"
        INSTALLED=1
    fi
fi

# Method 5: Try using PackageKit with dbus (alternative auth)
if [ "${INSTALLED}" = "0" ]; then
    echo "Trying method 5: PackageKit via dbus-send"
    if command -v dbus-send >/dev/null 2>&1; then
        # This is a long shot but worth trying
        RPM_PATH="file://${TMP_DIR}/${RPM_NAME}"
        if dbus-send --system --print-reply --dest=org.freedesktop.PackageKit \
            /org/freedesktop/PackageKit \
            org.freedesktop.PackageKit.InstallPackageFiles \
            array:string:"${RPM_PATH}" string:"hide-finished" 2>/dev/null; then
            echo "SUCCESS: Installed via PackageKit dbus"
            INSTALLED=1
        fi
    fi
fi

# Method 6: Copy to Downloads and show GUI instructions
if [ "${INSTALLED}" = "0" ]; then
    echo ""
    echo "Automatic installation failed. Preparing for GUI installation..."
    echo ""

    # Create Downloads directory if it doesn't exist
    mkdir -p "${DOWNLOADS_DIR}"

    # Copy RPM to Downloads folder
    cp "${TMP_DIR}/${RPM_NAME}" "${DOWNLOADS_DIR}/${RPM_NAME}"
    chmod 644 "${DOWNLOADS_DIR}/${RPM_NAME}"

    echo "RPM copied to: ${DOWNLOADS_DIR}/${RPM_NAME}"
    echo ""
    echo "=== ACTION REQUIRED ==="
    echo ""
    echo "Please do ONE of the following:"
    echo ""
    echo "Option A (Easiest - GUI):"
    echo "  1. Open the 'Files' app"
    echo "  2. Navigate to 'Downloads'"
    echo "  3. Tap on '${RPM_NAME}'"
    echo "  4. Select 'Install'"
    echo "  5. Enter your device lock code when prompted"
    echo ""
    echo "Option B (Terminal with Developer Mode):"
    echo "  1. Enable Developer Mode: Settings > System > Developer Mode"
    echo "  2. Set a developer password"
    echo "  3. Run: devel-su pkcon install-local ${DOWNLOADS_DIR}/${RPM_NAME}"
    echo ""
    echo "Option C (One-liner, needs Developer Mode):"
    echo "  devel-su pkcon install-local ${DOWNLOADS_DIR}/${RPM_NAME}"
    echo ""
    echo "After installation, run these commands to start the daemon:"
    echo ""
    echo "  systemctl --user daemon-reload"
    echo "  systemctl --user enable harbour-skodja.service"
    echo "  systemctl --user start harbour-skodja.service"
    echo "  systemctl --user status harbour-skodja.service"
    echo ""
    echo "=== End of script ==="
    exit 2
fi

# Clean up
rm -f "${TMP_DIR}/${RPM_NAME}"

echo ""
echo "--- Step 5: Reload systemd ---"
systemctl --user daemon-reload

echo "--- Step 6: Restart lipstick (for notification categories) ---"
systemctl --user restart lipstick 2>/dev/null || true

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

echo "--- Step 10: Start service ---"
if systemctl --user start harbour-skodja.service 2>/dev/null; then
    echo "Service started successfully"
else
    echo "WARNING: First start attempt failed, retrying..."
    sleep 3
    systemctl --user start harbour-skodja.service 2>/dev/null || echo "ERROR: Failed to start service"
fi

echo ""
echo "=== Checking status ==="
sleep 2
systemctl --user status harbour-skodja.service 2>/dev/null || true

echo ""
echo "=== Verifying daemon is running ==="
sleep 3
if systemctl --user is-active --quiet harbour-skodja.service; then
    echo ""
    echo "SUCCESS: Skoðja daemon is running!"
    echo ""
else
    echo ""
    echo "WARNING: Daemon is not running!"
    echo ""
    echo "--- Diagnostic information ---"
    echo ""
    echo "Service file:"
    cat /usr/lib/systemd/user/harbour-skodja.service 2>/dev/null || echo "(not found)"
    echo ""
    echo "Recent service logs:"
    journalctl --user -u harbour-skodja.service --no-pager -n 20 2>/dev/null || echo "(no logs)"
    echo ""
    echo "Wrapper logs:"
    journalctl -t harbour-skodja-wrapper --no-pager -n 20 2>/dev/null || echo "(no wrapper logs)"
    echo ""
    echo "--- Try running wrapper manually ---"
    timeout 10 /usr/share/harbour-skodja/daemon-wrapper.sh 5 2>&1 || true
fi

echo ""
echo "=== Recent logs (last 20 lines) ==="
journalctl --user -u harbour-skodja.service --no-pager -n 20 2>/dev/null || echo "(no journal access)"

echo ""
echo "=== Wrapper logs (last 20 lines) ==="
journalctl -t harbour-skodja-wrapper --no-pager -n 20 2>/dev/null || echo "(no wrapper logs)"

echo ""
echo "=== Done! ==="
echo "Skoðja ${VERSION} installed."
echo "The daemon checks GitHub every 60 seconds and sends notifications."
echo "Open the app to see activity and change settings."
echo ""
echo "Useful commands:"
echo "  systemctl --user status harbour-skodja.service  - Check if running"
echo "  journalctl -t harbour-skodja-wrapper -f          - Follow wrapper logs"
echo "  journalctl --user -u harbour-skodja.service -f   - Follow service logs"
