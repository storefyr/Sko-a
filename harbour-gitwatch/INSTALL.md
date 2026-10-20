# Installation af GitWatch på Jolla Phone 2026

## Forudsætninger

1. **Sailfish SDK** installeret på din udviklingsmaskine
2. **Developer mode** aktiveret på telefonen
3. **SSH adgang** til telefonen (eller USB kabel)

## Trin 1: Build app'en

```bash
cd harbour-gitwatch
chmod +x build.sh
./build.sh
```

Dette skaber `harbour-gitwatch-0.1.0.tar.bz2`.

## Trin 2: Build RPM pakken

```bash
# Installer Sailfish SDK hvis ikke allerede gjort
# Download fra: https://docs.sailfishos.org/Develop/Sailfish_SDK/

# Build for Jolla Phone 2026 (aarch64)
sb2 -t SailfishOS-latest-aarch64 -R rpmbuild -ta harbour-gitwatch-0.1.0.tar.bz2
```

## Trin 3: Installer på telefonen

### Via SSH/SCP:

```bash
# Kopier RPM til telefonen
scp harbour-gitwatch-0.1.0-1.noarch.rpm nemo@<telefon-ip>:/home/nemo/

# SSH ind på telefonen
ssh nemo@<telefon-ip>

# Installer
pkcon install-local harbour-gitwatch-0.1.0-1.noarch.rpm
```

### Eller direkte på telefonen:

1. Kopier `.rpm` filen til telefonens Downloads mappe
2. Åbn Terminal appen på telefonen
3. Kør: `pkcon install-local ~/Downloads/harbour-gitwatch-0.1.0-1.noarch.rpm`

## Trin 4: Aktiver baggrundstjek

Efter installation aktiveres baggrundstjek automatisk. Du kan også gøre det manuelt:

```bash
# Aktiver timer
systemctl --user enable harbour-gitwatch.timer
systemctl --user start harbour-gitwatch.timer

# Tjek status
systemctl --user status harbour-gitwatch.timer
```

## Trin 5: Åbn app'en

1. Find "GitWatch" i app-listen på telefonen
2. Åbn app'en - den viser seneste aktivitet for `storefyr`
3. Gå til **Indstillinger** (træk ned fra toppen) for at tilføje flere brugere

## Fejlfinding

### Ingen notifikationer?

```bash
# Tjek om timeren kører
systemctl --user list-timers | grep gitwatch

# Se logfiler
journalctl --user -u harbour-gitwatch.service -n 50

# Kør manuel tjek
systemctl --user start harbour-gitwatch.service
```

### App'en viser ingen data?

1. Tjek internetforbindelse
2. Træk ned for at opdatere manuelt
3. Tjek at `storefyr` er tilføjet som overvåget bruger

## Afinstallation

```bash
# Stop og deaktiver timer
systemctl --user stop harbour-gitwatch.timer
systemctl --user disable harbour-gitwatch.timer

# Fjern pakke
pkcon remove harbour-gitwatch

# Slet data (valgfrit)
rm -rf ~/.local/share/harbour-gitwatch
```
