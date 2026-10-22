#!/bin/sh
# Skoðja update script — VIDERESTILLER TIL install.sh
# Denne fil er bevaret for bagudkompatibilitet.
# Brug install.sh i stedet for — den downloader til Downloads
# og giver instruktioner til installation via Files app.
#
# Brug:
#   curl -LO https://raw.githubusercontent.com/storefyr/Sko-a/main/harbour-skodja/install.sh && sh install.sh

VERSION="${1:-0.9.11}"

echo ""
echo "  OBS: update.sh er blevet erstattet af install.sh"
echo ""
echo "  Kør i stedet:"
echo "    curl -LO https://raw.githubusercontent.com/storefyr/Sko-a/main/harbour-skodja/install.sh && sh install.sh ${VERSION}"
echo ""
echo "  Henter og kører install.sh nu..."
echo ""

# Hent og kør install.sh
curl -sL https://raw.githubusercontent.com/storefyr/Sko-a/main/harbour-skodja/install.sh | sh -s "${VERSION}"
