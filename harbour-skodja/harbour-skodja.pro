# harbour-skodja - GitHub Activity Notifier for Sailfish OS
# Copyright (C) 2026 storefyr
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

TARGET = harbour-skodja

CONFIG += sailfishapp

QT += qml quick

SOURCES += src/main.cpp

OTHER_FILES += \
    qml/harbour-skodja.qml \
    qml/pages/MainPage.qml \
    qml/pages/SettingsPage.qml \
    qml/cover/CoverPage.qml \
    qml/background-check.qml \
    qml/skodja-daemon.qml \
    python/gitwatch/__init__.py \
    python/gitwatch/github_client.py \
    rpm/harbour-skodja.spec \
    harbour-skodja.desktop \
    icons/*.png \
    sounds/notification.wav \
    config/x-harbour.harbour-skodja.event.conf \
    config/x-harbour.harbour-skodja.release.conf \
    README.md \
    INSTALL.md \
    QUICKSTART.md \
    build.sh

SAILFISHAPP_ICONS = 86x86 108x108 128x128 256x256

DISTFILES += \
    qml/harbour-skodja.qml \
    qml/pages/MainPage.qml \
    qml/pages/SettingsPage.qml \
    qml/cover/CoverPage.qml \
    qml/background-check.qml \
    qml/skodja-daemon.qml \
    python/gitwatch/__init__.py \
    python/gitwatch/github_client.py \
    harbour-skodja.desktop \
    config/x-harbour.harbour-skodja.event.conf \
    config/x-harbour.harbour-skodja.release.conf
