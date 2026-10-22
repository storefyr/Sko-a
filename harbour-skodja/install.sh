#!/bin/sh
# Skoðja install script — kør på Sailfish OS telefonen
# Download og kør dette script direkte:
#   curl -LO https://raw.githubusercontent.com/storefyr/Sko-a/main/harbour-skodja/install.sh && sh install.sh
#
# Eller med specifik version:
#   curl -LO https://raw.githubusercontent.com/storefyr/Sko-a/main/harbour-skodja/install.sh && sh install.sh 0.9.10

VERSION="${1:-0.9.10}"
UPDATE_SCRIPT_URL="https://raw.githubusercontent.com/storefyr/Sko-a/main/harbour-skodja/update.sh"

echo ""
echo "=== Skoðja Install ==="
echo "  Version: v${VERSION}"
echo ""

echo "Henter update script..."
TMP_SCRIPT="/tmp/skodja-update.sh"
curl -sL -o "${TMP_SCRIPT}" "${UPDATE_SCRIPT_URL}"

if [ ! -s "${TMP_SCRIPT}" ]; then
    echo "FEJL: Kunne ikke hente update script"
    exit 1
fi

echo "Kører update script..."
echo ""
sh "${TMP_SCRIPT}" "${VERSION}"
EXIT_CODE=$?

rm -f "${TMP_SCRIPT}"
exit $EXIT_CODE
