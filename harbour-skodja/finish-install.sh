#!/bin/sh
# Skoðja finish-install script - run AFTER installing the RPM
# Usage: sh finish-install.sh
# Or download and run directly:
#   curl -sL https://raw.githubusercontent.com/storefyr/Sko-a/main/harbour-skodja/finish-install.sh | sh
#
# This script sets up and starts the daemon after manual RPM installation.

echo "=== Skoðja Finish Install ==="
echo ""

echo "--- Step 1: Stop any old service ---"
systemctl --user stop harbour-skodja.service 2>/dev/null && echo "Stopped old service" || echo "No old service running"

echo "--- Step 2: Reload systemd ---"
systemctl --user daemon-reload
echo "Done"

echo "--- Step 3: Restart lipstick (for notification categories) ---"
systemctl --user restart lipstick 2>/dev/null && echo "Lipstick restarted" || echo "Could not restart lipstick (OK)"

echo "--- Step 4: Enable service ---"
if systemctl --user enable harbour-skodja.service 2>/dev/null; then
    echo "Service enabled (will start at login)"
else
    echo "WARNING: Could not enable service"
fi

echo "--- Step 5: Clean up old daemon processes ---"
pkill -f "github_client.py" 2>/dev/null && echo "Killed old daemon processes" || echo "No old processes to kill"
sleep 1

echo "--- Step 6: Clear stale lock files ---"
LOCK_FILE="${HOME}/.local/share/com.storefyr/harbour-skodja/state.lock"
if [ -f "${LOCK_FILE}" ]; then
    rm -f "${LOCK_FILE}"
    echo "Removed stale lock file"
else
    echo "No stale lock file"
fi

echo "--- Step 7: Verify installation ---"
echo ""
echo "Checking files:"
echo -n "  Service file: "
if [ -f /usr/lib/systemd/user/harbour-skodja.service ]; then
    echo "OK"
else
    echo "MISSING!"
    echo "ERROR: Service file not found. Installation may have failed."
    exit 1
fi

echo -n "  Python script: "
if [ -f /usr/share/harbour-skodja/python/gitwatch/github_client.py ]; then
    echo "OK"
else
    echo "MISSING!"
    echo "ERROR: Python script not found. Installation may have failed."
    exit 1
fi

echo -n "  Wrapper script: "
if [ -f /usr/share/harbour-skodja/daemon-wrapper.sh ]; then
    echo "OK"
else
    echo "MISSING!"
fi

echo -n "  Desktop file: "
if [ -f /usr/share/applications/harbour-skodja.desktop ]; then
    echo "OK"
else
    echo "MISSING!"
fi

echo ""
echo "--- Step 8: Start service ---"
if systemctl --user start harbour-skodja.service 2>/dev/null; then
    echo "Service started"
else
    echo "First attempt failed, retrying..."
    sleep 3
    if systemctl --user start harbour-skodja.service 2>/dev/null; then
        echo "Service started (on retry)"
    else
        echo "ERROR: Could not start service"
    fi
fi

echo ""
echo "--- Step 9: Check status ---"
sleep 2
systemctl --user status harbour-skodja.service 2>/dev/null || true

echo ""
echo "--- Step 10: Verify daemon is running ---"
sleep 3
if systemctl --user is-active --quiet harbour-skodja.service; then
    echo ""
    echo "SUCCESS: Skoðja daemon is running!"
    echo ""
    echo "The daemon will check GitHub every 60 seconds."
    echo "Open the Skoðja app to configure settings."
else
    echo ""
    echo "WARNING: Daemon is not running!"
    echo ""
    echo "=== Diagnostic Information ==="
    echo ""
    echo "Service file contents:"
    cat /usr/lib/systemd/user/harbour-skodja.service 2>/dev/null || echo "(cannot read)"
    echo ""
    echo "Data directory:"
    ls -la "${HOME}/.local/share/com.storefyr/harbour-skodja/" 2>/dev/null || echo "(not found)"
    echo ""
    echo "Recent service logs:"
    journalctl --user -u harbour-skodja.service --no-pager -n 20 2>/dev/null || echo "(no logs)"
    echo ""
    echo "Wrapper logs:"
    journalctl -t harbour-skodja-wrapper --no-pager -n 20 2>/dev/null || echo "(no wrapper logs)"
    echo ""
    echo "Try running wrapper manually:"
    echo "  /usr/share/harbour-skodja/daemon-wrapper.sh 5"
fi

echo ""
echo "=== Useful commands ==="
echo "  systemctl --user status harbour-skodja.service   Check status"
echo "  systemctl --user restart harbour-skodja.service  Restart daemon"
echo "  journalctl -t harbour-skodja-wrapper -f           Follow wrapper logs"
echo "  journalctl --user -u harbour-skodja.service -f    Follow service logs"
echo ""
echo "=== Done! ==="
