#!/bin/sh
# Wrapper script for harbour-skodja daemon
# Logs everything to journal for debugging

LOG_TAG="harbour-skodja-wrapper"

log() {
    /usr/bin/logger -t "$LOG_TAG" "$1"
    echo "$1"
}

log "=== Wrapper starting ==="
log "PID: $$"
log "HOME=$HOME"
log "USER=$USER"
log "XDG_DATA_HOME=$XDG_DATA_HOME"
log "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
log "DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS"
log "PATH=$PATH"
log "Arguments: $@"

SCRIPT="/usr/share/harbour-skodja/python/gitwatch/github_client.py"

log "Checking if script exists: $SCRIPT"
if [ ! -f "$SCRIPT" ]; then
    log "FATAL: Script not found: $SCRIPT"
    exit 1
fi

log "Checking if python3 exists"
if ! command -v python3 >/dev/null 2>&1; then
    log "FATAL: python3 not found in PATH"
    exit 1
fi
log "python3 path: $(command -v python3)"

log "Starting daemon..."
exec /usr/bin/python3 "$SCRIPT" "$@"
