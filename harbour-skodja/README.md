# Skoða

En Sailfish OS app der giver notifikationer når der er ny aktivitet på GitHub-profiler.

## Funktioner

- Overvåger GitHub-brugere (starter med `storefyr`)
- Viser seneste aktivitet: pushes, pull requests, issues, releases, nye repos
- Kører som baggrundsdaemon (tjekker hvert minut)
- Viser systemnotifikationer ved ny aktivitet
- Lyd via Sailfish OS indstillinger (kun ved nye releases)
- Tilføj/fjern brugere du vil følge

## Installation

### Fra kildekode (udvikling)

1. Installer Sailfish SDK
2. Åbn projektet i Sailfish IDE (Qt Creator)
3. Vælg build target (f.eks. SailfishOS-5.x-aarch64)
4. Build og deploy til emulator eller telefon

### Manuelt på telefonen

```bash
# Installer afhængigheder
pkcon install pyotherside-qml-plugin-python3-qt5 python3-requests

# Kopier filer
mkdir -p /usr/share/harbour-skodja
cp -r qml python /usr/share/harbour-skodja/

# Opret launcher
cat > /usr/share/applications/harbour-skodja.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Skoða
Exec=/usr/bin/invoker --type=qt5 -s /usr/bin/sailfish-qml /usr/share/harbour-skodja/qml/harbour-skodja.qml
Icon=harbour-skodja
X-Nemo-Application-Type=silica-qt5
EOF

# Aktiver baggrundsdaemon
systemctl --user enable --now harbour-skodja.service
```

## Arkitektur

- **QML UI**: Sailfish Silica komponenter
- **Python backend**: PyOtherSide til GitHub API kald
- **Baggrundsdaemon**: systemd user service (kører kontinuerligt)
