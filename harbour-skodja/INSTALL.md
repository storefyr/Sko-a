# Installation af Skoða på Jolla Phone 2026

## Forudsætninger

1. **Sailfish SDK** installeret på din udviklingsmaskine
2. **Developer mode** aktiveret på telefonen
3. **SSH adgang** til telefonen (eller USB kabel)

## Trin 1: Build app'en

```bash
cd harbour-skodja
chmod +x build.sh
./build.sh
```

Dette skaber `harbour-skodja-0.6.0.tar.bz2`.

## Trin 2: Build RPM pakken

```bash
# Installer Sailfish SDK hvis ikke allerede gjort
# Download fra: https://docs.sailfishos.org/Develop/Sailfish_SDK/

# Build for Jolla Phone 2026 (aarch64)
sb2 -t SailfishOS-latest-aarch64 -R rpmbuild -ta harbour-skodja-0.6.0.tar.bz2
```

## Trin 3: Installer på telefonen

### Via SSH/SCP:

```bash
# Kopier RPM til telefonen
scp harbour-skodja-0.6.0-1.noarch.rpm nemo@<telefon-ip>:/home/nemo/

# SSH ind på telefonen
ssh nemo@<telefon-ip>

# Installer
pkcon install-local harbour-skodja-0.6.0-1.noarch.rpm
```

### Eller direkte på telefonen:

1. Kopier `.rpm` filen til telefonens Downloads mappe
2. Åbn Terminal appen på telefonen
3. Kør: `pkcon install-local ~/Downloads/harbour-skodja-0.6.0-1.noarch.rpm`

## Trin 4: Aktiver baggrundsdaemon

Efter installation aktiveres baggrundsdaemonen automatisk. Du kan også gøre det manuelt:

```bash
# Aktiver daemon
systemctl --user enable harbour-skodja.service
systemctl --user start harbour-skodja.service

# Tjek status
systemctl --user status harbour-skodja.service
```

## Trin 5: Åbn app'en

1. Find "Skoða" i app-listen på telefonen
2. Åbn app'en - den viser seneste aktivitet for `storefyr`
3. Gå til **Indstillinger** (træk ned fra toppen) for at tilføje flere brugere

## Fejlfinding

### Ingen notifikationer?

```bash
# Tjek om daemonen kører
systemctl --user status harbour-skodja.service

# Se logfiler
journalctl --user -u harbour-skodja.service -n 50

# Genstart daemon
systemctl --user restart harbour-skodja.service
```

### App'en viser ingen data?

1. Tjek internetforbindelse
2. Træk ned for at opdatere manuelt
3. Tjek at `storefyr` er tilføjet som overvåget bruger

## Afinstallation

```bash
# Stop og deaktiver daemon
systemctl --user stop harbour-skodja.service
systemctl --user disable harbour-skodja.service

# Fjern pakke
pkcon remove harbour-skodja

# Slet data (valgfrit)
rm -rf ~/.local/share/harbour-skodja
```
