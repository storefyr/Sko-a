TEMPLATE = app
TARGET = harbour-gitwatch

QT += qml quick
CONFIG += sailfishapp

SOURCES += 

OTHER_FILES += \
    qml/harbour-gitwatch.qml \
    qml/pages/MainPage.qml \
    qml/pages/SettingsPage.qml \
    qml/cover/CoverPage.qml \
    qml/background-check.qml \
    python/gitwatch/__init__.py \
    python/gitwatch/github_client.py \
    rpm/harbour-gitwatch.yaml \
    rpm/harbour-gitwatch.spec \
    icons/*.png \
    README.md \
    INSTALL.md \
    build.sh

SAILFISHAPP_ICONS = 86x86 108x108 128x128 256x256

DISTFILES += \
    qml/harbour-gitwatch.qml \
    qml/pages/MainPage.qml \
    qml/pages/SettingsPage.qml \
    qml/cover/CoverPage.qml \
    qml/background-check.qml
