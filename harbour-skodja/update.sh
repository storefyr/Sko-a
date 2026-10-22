#!/bin/sh
# Skoðja opdateringsskript — kør på Sailfish OS telefonen
# Henter og installerer seneste version fra GitHub Releases.
# Stopper gammel daemon, installerer ny RPM, genstarter daemon.
#
# Brug:
#   curl -LO https://raw.githubusercontent.com/storefyr/Sko-a/main/harbour-skodja/update.sh && sh update.sh
#
# Valgfrit — angiv en specifik version:
#   sh update.sh 0.9.10
#
# Valgfrit — spring daemon-genstart over:
#   sh update.sh 0.9.10 --no-restart

set -e

# --- Konfiguration ---
REPO="storefyr/Sko-a"
DEFAULT_VERSION="0.9.10"
VERSION="${1:-${DEFAULT_VERSION}}"
NO_RESTART=""
if [ "$2" = "--no-restart" ]; then
    NO_RESTART="yes"
elif [ "$1" = "--no-restart" ]; then
    NO_RESTART="yes"
    VERSION="${DEFAULT_VERSION}"
fi
ARCH="aarch64"
RPM_NAME="harbour-skodja-${VERSION}-1.${ARCH}.rpm"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/v${VERSION}/${RPM_NAME}"
TMP_FILE="/tmp/${RPM_NAME}"

echo ""
echo "=== Skoðja Update Script ==="
echo "  Version: v${VERSION}"
echo "  Architecture: ${ARCH}"
echo "  Target: Jolla Phone 2026 (Sailfish OS)"
echo ""

# --- Trin 1: Tjek om vi kører på Sailfish OS ---
if ! command -v pkcon >/dev/null 2>&1; then
    echo "FEJL: pkcon ikke fundet — kører du dette på en Sailfish OS telefon?"
    exit 1
fi

# --- Trin 2: Stop gammel daemon ---
echo "--- Trin 1/6: Stopper gammel daemon ---"
if systemctl --user is-active --quiet harbour-skodja.service 2>/dev/null; then
    systemctl --user stop harbour-skodja.service
    echo "  Daemon stoppet"
else
    echo "  Daemon var ikke kørende — springer over"
fi
# Dræb også manuelle instanser
pkill -f "github_client.py" 2>/dev/null || true
pkill -f "daemon-wrapper.sh" 2>/dev/null || true
echo ""

# --- Trin 3: Ryd gamle låse-filer ---
echo "--- Trin 2/6: Rydder gamle låse-filer ---"
LOCK_FILE="${HOME}/.local/share/com.storefyr/harbour-skodja/state.lock"
if [ -f "${LOCK_FILE}" ]; then
    rm -f "${LOCK_FILE}"
    echo "  Fjernede stale låse-fil"
else
    echo "  Ingen låse-fil at fjerne"
fi
echo ""

# --- Trin 4: Download ny RPM ---
echo "--- Trin 3/6: Henter Skoðja v${VERSION} ---"
echo "  URL: ${DOWNLOAD_URL}"
rm -f "${TMP_FILE}"
curl -sL -o "${TMP_FILE}" "${DOWNLOAD_URL}"

# Tjek at download faktisk er en RPM
if [ ! -s "${TMP_FILE}" ]; then
    echo "FEJL: Download fejlede — filen er tom"
    exit 1
fi
if ! head -c 4 "${TMP_FILE}" | od -An -tx1 | grep -q "ed ab ee db"; then
    echo "FEJL: Downloadet fil er ikke en gyldig RPM"
    echo "  (Måske findes version v${VERSION} ikke?)"
    head -c 200 "${TMP_FILE}"
    echo ""
    rm -f "${TMP_FILE}"
    exit 1
fi
echo "  Download færdig: $(wc -c < "${TMP_FILE}" | tr -d ' ') bytes"
echo ""

# --- Trin 5: Installer ---
echo "--- Trin 4/6: Installerer Skoðja v${VERSION} ---"
echo ""

# pkcon install-local kræver interaktion (popup med sikkerhedskode).
# Vi kører den direkte på terminalen — IKKE i baggrunden — så popup'en
# har adgang til skærmen og kan modtage input.
# Hvis scriptet køres via 'curl | sh', vil stdin være lukket, så vi
# omdirigerer fra /dev/tty for at sikre terminal-adgang.

if [ -t 0 ]; then
    # Normal terminal — kør direkte
    pkcon install-local "${TMP_FILE}"
    PKCON_EXIT=$?
else
    # Kørt via curl | sh — stdin er ikke en terminal
    # Forsøg at åbne /dev/tty direkte
    echo "  ADVARSEL: Scriptet kører ikke i en terminal (curl | sh)."
    echo "  Prøver at redirecte fra /dev/tty..."
    echo ""
    if pkcon install-local "${TMP_FILE}" < /dev/tty; then
        PKCON_EXIT=0
    else
        PKCON_EXIT=$?
    fi
fi

if [ $PKCON_EXIT -ne 0 ]; then
    echo ""
    echo "  FEJL: Installation fejlede (exit code: $PKCON_EXIT)"
    echo ""
    echo "  Hvis popup'en ikke dukkede op, kør manuelt:"
    echo "    pkcon install-local ${TMP_FILE}"
    echo "  (Så kan du se popup'en og indtaste sikkerhedskoden)"
    echo ""
    echo "  Efter manuel installation, kør:"
    echo "    systemctl --user daemon-reload"
    echo "    systemctl --user enable --now harbour-skodja.service"
    exit 1
fi
echo "  Installation OK"
echo ""

# --- Trin 6: Reload systemd og genstart lipstick ---
echo "--- Trin 5/6: Genindlæser systemd og lipstick ---"
systemctl --user daemon-reload
systemctl --user restart lipstick 2>/dev/null || true
echo "  Systemd genindlæst, lipstick genstartet"
echo ""

# --- Trin 7: Aktiver og start daemon ---
if [ "$NO_RESTART" = "yes" ]; then
    echo "--- Trin 6/6: Daemon-genstart SKIPPET (--no-restart) ---"
    systemctl --user enable harbour-skodja.service 2>/dev/null || true
    echo "  Service aktiveret (starter ved næste login)"
else
    echo "--- Trin 6/6: Aktiverer og starter daemon ---"
    systemctl --user enable harbour-skodja.service 2>/dev/null || true
    if systemctl --user start harbour-skodja.service 2>/dev/null; then
        echo "  Daemon startet"
    else
        sleep 2
        systemctl --user start harbour-skodja.service 2>/dev/null && echo "  Daemon startet (efter retry)" || echo "  ADVARSEL: Kunne ikke starte daemon"
    fi
fi
echo ""

# --- Trin 8: Ryd op og verificer ---
echo "--- Verificerer ---"
rm -f "${TMP_FILE}"
sleep 2

if systemctl --user is-active --quiet harbour-skodja.service 2>/dev/null; then
    echo ""
    echo "  ✅ Skoðja v${VERSION} er installeret og kører!"
    echo ""
    echo "  Daemon tjekker GitHub hvert 60. sekund."
    echo "  Åbn Skoðja app'en for at se aktivitet og ændre indstillinger."
    echo ""
    echo "  Nyttige kommandoer:"
    echo "    systemctl --user status harbour-skodja.service   Se status"
    echo "    journalctl -t harbour-skodja-wrapper -f          Følg wrapper logs"
    echo "    journalctl --user -u harbour-skodja.service -f   Følg service logs"
    echo ""
else
    echo ""
    echo "  ⚠️  Installation OK, men daemon kører ikke endnu."
    echo ""
    echo "  Prøv at starte den manuelt:"
    echo "    systemctl --user start harbour-skodja.service"
    echo ""
    echo "  Se logs for fejlfinding:"
    echo "    journalctl --user -u harbour-skodja.service -n 30 --no-pager"
    echo "    journalctl -t harbour-skodja-wrapper -n 30 --no-pager"
    echo ""
fi
