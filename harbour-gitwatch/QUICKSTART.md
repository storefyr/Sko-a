# GitWatch v0.1.0 - Hurtig start

## 1. Download udgivelsen

```bash
# Download source tarball fra GitHub Releases
gh release download v0.1.0 --repo storefyr/Sko-a --pattern "*.tar.bz2"

# Eller direkte fra browser:
# https://github.com/storefyr/Sko-a/releases/tag/v0.1.0
```

## 2. Udpak og byg RPM

```bash
# Udpak
tar -xjf harbour-gitwatch-0.1.0.tar.bz2
cd harbour-gitwatch-0.1.0

# Installer Sailfish SDK først (hvis ikke gjort):
# https://docs.sailfishos.org/Develop/Sailfish_SDK/Installation/

# Byg RPM til Jolla Phone 2026 (aarch64)
sb2 -t SailfishOS-latest-aarch64 -R rpmbuild -ta harbour-gitwatch-0.1.0.tar.bz2
```

## 3. Find den byggede RPM

```bash
# RPM ligger typisk her:
~/SailfishOS/rpmbuild/RPMS/noarch/harbour-gitwatch-0.1.0-1.noarch.rpm
```

## 4. Installer på telefonen

```bash
# Kopier til telefonen
scp ~/SailfishOS/rpmbuild/RPMS/noarch/harbour-gitwatch-0.1.0-1.noarch.rpm nemo@<telefon-ip>:/home/nemo/

# Eller brug USB kabel og kopier manuelt

# SSH ind og installer
ssh nemo@<telefon-ip>
pkcon install-local harbour-gitwatch-0.1.0-1.noarch.rpm
```

## 5. Aktiver baggrundstjek

```bash
# På telefonen
systemctl --user enable harbour-gitwatch.timer
systemctl --user start harbour-gitwatch.timer

# Verificer
systemctl --user status harbour-gitwatch.timer
```

## 6. Åbn app'en

1. Find **GitWatch** i app-listen
2. App'en starter med at overvåge `storefyr`
3. Træk ned for at opdatere manuelt
4. Gå til **Indstillinger** for at tilføje flere brugere

## Fejlfinding

```bash
# Se logs
journalctl --user -u harbour-gitwatch.service -n 50

# Manuel tjek
systemctl --user start harbour-gitwatch.service

# Tjek timer status
systemctl --user list-timers | grep gitwatch
```

## Links

- **Release:** https://github.com/storefyr/Sko-a/releases/tag/v0.1.0
- **Dokumentation:** https://github.com/storefyr/Sko-a/tree/main/harbour-gitwatch
- **Issues:** https://github.com/storefyr/Sko-a/issues
