# Sko-a

Samling af projekter til Jolla Phone 2026 (Sailfish OS).

## Projekter

### harbour-gitwatch

[![CI](https://github.com/storefyr/Sko-a/actions/workflows/ci.yml/badge.svg)](https://github.com/storefyr/Sko-a/actions/workflows/ci.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

GitHub Activity Notifier for Sailfish OS. Få notifikationer når der er ny aktivitet på GitHub-profiler.

- Overvåger GitHub-brugere for pushes, pull requests, issues og releases
- Baggrundstjek hver 30. minut via systemd timer
- Dansk sprog UI
- Se [harbour-gitwatch/README.md](harbour-gitwatch/README.md) for detaljer
- Se [harbour-gitwatch/INSTALL.md](harbour-gitwatch/INSTALL.md) for installation

## CI/CD

Projektet bruger GitHub Actions til CI/CD:

- **CI** (`.github/workflows/ci.yml`): Kører på push/PR til `main`
  - Python tests på flere versioner (3.9-3.12)
  - Lint (flake8, black, mypy)
  - RPM packaging validering
  - QML validering
  - Source tarball build

- **Release** (`.github/workflows/release.yml`): Kører ved git tags (`v*`)
  - Kører tests først
  - Opretter source tarball
  - Publicerer GitHub Release

## Licens

GPL-3.0 - se [LICENSE](LICENSE)
