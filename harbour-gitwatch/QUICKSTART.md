# Skoða v0.5.2 - Hurtig start

## Download færdigbygget RPM

Gå til [Releases](https://github.com/storefyr/Sko-a/releases) og download RPM til din enhed:

| Fil | Enhed |
|-----|-------|
| `harbour-gitwatch-0.5.2-aarch64.rpm` | **Jolla Phone 2026** (ARM64) |
| `harbour-gitwatch-0.5.2-armv7hl.rpm` | 32-bit ARM enheder |
| `harbour-gitwatch-0.5.2-i486.rpm` | Emulator (x86) |

## Installation på Jolla Phone 2026

```bash
# 1. Kopier RPM til telefonen
scp harbour-gitwatch-0.5.2-aarch64.rpm nemo@<telefon-ip>:/home/nemo/

# 2. SSH ind på telefonen
ssh nemo@<telefon-ip>

# 3. Installer
pkcon install-local harbour-gitwatch-0.5.2-aarch64.rpm

# 4. Verificer at baggrundsdaemon kører
systemctl --user status harbour-gitwatch.service
```

## Manuel aktivering af baggrundsdaemon

```bash
systemctl --user enable harbour-gitwatch.service
systemctl --user start harbour-gitwatch.service
```

## Åbn app'en

1. Find **Skoða** i app-listen
2. App'en starter med at overvåge `storefyr`
3. Træk ned for at opdatere manuelt
4. Gå til **Indstillinger** for at tilføje flere brugere

## Byg selv fra kildekode

Hvis du vil bygge selv:

```bash
# Download source tarball fra Releases, eller klon repo
git clone https://github.com/storefyr/Sko-a.git
cd Sko-a/harbour-gitwatch

# Installer Sailfish SDK
# https://docs.sailfishos.org/Develop/Sailfish_SDK/Installation/

# Byg RPM
mb2 -t SailfishOS-latest-aarch64 build

# Find RPM i RPMS/ mappen
ls -lh RPMS/
```

## Fejlfinding

```bash
# Se logs
journalctl --user -u harbour-gitwatch.service -n 50

# Genstart daemon
systemctl --user restart harbour-gitwatch.service

# Tjek daemon status
systemctl --user status harbour-gitwatch.service
```

## CI/CD

Projektet bygges automatisk med GitHub Actions:

- **CI**: Tester, lint, validering og RPM build ved hver push/PR
- **Release**: Bygger RPM'er til alle arkitekturer ved git tags (`v*`)

Se `.github/workflows/` for detaljer.

## Links

- **Releases:** https://github.com/storefyr/Sko-a/releases
- **Dokumentation:** https://github.com/storefyr/Sko-a/tree/main/harbour-gitwatch
- **Issues:** https://github.com/storefyr/Sko-a/issues
- **CI Status:** https://github.com/storefyr/Sko-a/actions
