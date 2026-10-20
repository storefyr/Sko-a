# harbour-gitwatch

En Sailfish OS app der giver notifikationer når der er ny aktivitet på GitHub-profiler.

## Funktioner

- Overvåger GitHub-brugere (starter med `storefyr`)
- Viser seneste aktivitet: pushes, pull requests, issues, releases, nye repos
- Kører baggrundstjek hver 30. minut via systemd timer
- Viser systemnotifikationer ved ny aktivitet
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
mkdir -p /usr/share/harbour-gitwatch
cp -r qml python /usr/share/harbour-gitwatch/

# Opret launcher
cat > /usr/share/applications/harbour-gitwatch.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=GitWatch
Exec=/usr/bin/invoker --type=qt5 -s /usr/bin/sailfish-qml /usr/share/harbour-gitwatch/qml/harbour-gitwatch.qml
Icon=harbour-gitwatch
X-Nemo-Application-Type=silica-qt5
EOF

# Aktiver baggrundstjek
systemctl --user enable --now harbour-gitwatch.timer
```

## Arkitektur

- **QML UI**: Sailfish Silica komponenter
- **Python backend**: PyOtherSide til GitHub API kald
- **Baggrundstjek**: systemd user timer hver 30. minut
- **Notifikationer**: D-Bus via `org.freedesktop.Notifications`
- **State**: Gemmes i `~/.local/share/harbour-gitwatch/state.json`

## GitHub API

App'en bruger GitHub REST API v3 uden autentifikation.
Rate limit: 60 requests/time for uautentificerede kald.

## Licens

MIT
