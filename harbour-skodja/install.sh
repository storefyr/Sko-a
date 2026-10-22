#!/bin/sh
# Skoðja install script — kør på Sailfish OS telefonen
# Downloader RPM til Downloads og viser instruktioner til installation.
# Efter installation via Files app, kør finish-install.sh
#
# Brug:
#   curl -LO https://raw.githubusercontent.com/storefyr/Sko-a/main/harbour-skodja/install.sh && sh install.sh
#
# Valgfrit — angiv en specifik version:
#   sh install.sh 0.9.11

VERSION="${1:-0.9.11}"
ARCH="aarch64"
RPM_NAME="harbour-skodja-${VERSION}-1.${ARCH}.rpm"
DOWNLOAD_URL="https://github.com/storefyr/Sko-a/releases/download/v${VERSION}/${RPM_NAME}"
DOWNLOADS_DIR="${HOME}/Downloads"

echo ""
echo "  ============================================"
echo "   Skoðja v${VERSION} — Installation"
echo "   Jolla Phone 2026 (Sailfish OS)"
echo "  ============================================"
echo ""

# Tjek om vi kører på Sailfish OS
if ! command -v pkcon >/dev/null 2>&1; then
    echo "FEJL: pkcon ikke fundet — kører du dette på en Sailfish OS telefon?"
    exit 1
fi

# Stop gammel daemon hvis den kører
echo "--- Trin 1/4: Stopper gammel daemon ---"
if systemctl --user is-active --quiet harbour-skodja.service 2>/dev/null; then
    systemctl --user stop harbour-skodja.service
    echo "  Daemon stoppet"
else
    echo "  Daemon var ikke kørende"
fi
pkill -f "github_client.py" 2>/dev/null || true
pkill -f "daemon-wrapper.sh" 2>/dev/null || true
echo ""

# Ryd låse-filer
echo "--- Trin 2/4: Rydder gamle låse-filer ---"
LOCK_FILE="${HOME}/.local/share/com.storefyr/harbour-skodja/state.lock"
if [ -f "${LOCK_FILE}" ]; then
    rm -f "${LOCK_FILE}"
    echo "  Fjernede stale låse-fil"
else
    echo "  Ingen låse-fil at fjerne"
fi
echo ""

# Opret Downloads mappe hvis den ikke findes
echo "--- Trin 3/4: Downloader Skoðja v${VERSION} ---"
mkdir -p "${DOWNLOADS_DIR}"
TARGET_FILE="${DOWNLOADS_DIR}/${RPM_NAME}"

rm -f "${TARGET_FILE}"
echo "  URL: ${DOWNLOAD_URL}"
curl -sL -o "${TARGET_FILE}" "${DOWNLOAD_URL}"

# Verificer download
if [ ! -s "${TARGET_FILE}" ]; then
    echo "  FEJL: Download fejlede — filen er tom"
    exit 1
fi
if ! head -c 4 "${TARGET_FILE}" | od -An -tx1 | grep -q "ed ab ee db"; then
    echo "  FEJL: Downloadet fil er ikke en gyldig RPM"
    echo "  (Måske findes version v${VERSION} ikke?)"
    rm -f "${TARGET_FILE}"
    exit 1
fi
echo "  Download færdig: $(wc -c < "${TARGET_FILE}" | tr -d ' ') bytes"
echo "  Gem location: ${TARGET_FILE}"
echo ""

# Instruktioner
echo "--- Trin 4/4: Installation via Files app ---"
echo ""
echo "  ============================================"
echo "   NÆSTE SKRIDT — Installer RPM manuelt:"
echo "  ============================================"
echo ""
echo "  1. Åbn 'Files' app'en (Filhåndtering)"
echo "  2. Gå til mappen: Downloads"
echo "  3. Tryk på filen: ${RPM_NAME}"
echo "  4. Vælg 'Install' (Installer)"
echo "  5. Indtast din enheds sikkerhedskode når du bliver bedt om det"
echo "     (Dette er IKKE developer password — det er din almindelige"
echo "      telefons låsekode, f.eks. 1234 eller din PIN)"
echo ""
echo "  ============================================"
echo "   EFTER INSTALLATION — Kør dette for at starte:"
echo "  ============================================"
echo ""
echo "  curl -sL https://raw.githubusercontent.com/storefyr/Sko-a/main/harbour-skodja/finish-install.sh | sh"
echo ""
echo "  Eller kør manuelt:"
echo "    systemctl --user daemon-reload"
echo "    systemctl --user enable --now harbour-skodja.service"
echo "    systemctl --user status harbour-skodja.service"
echo ""
