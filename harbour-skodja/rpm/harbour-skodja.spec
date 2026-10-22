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

%define __provides_exclude_from ^%{_datadir}/%{name}/python/.*$
%define __requires_exclude ^python3.*$

Name:           harbour-skodja
Summary:        Skoðja - GitHub Activity Notifier
Version:        0.9.11
Release:        1
Group:          Applications/Internet
License:        GPL-3.0
URL:            https://github.com/storefyr/Sko-a/tree/main/harbour-skodja
Source0:        %{name}-%{version}.tar.bz2

Requires:       sailfishsilica-qt5 >= 0.10.9
Requires:       pyotherside-qml-plugin-python3-qt5 >= 1.3.0
Requires:       python3-base

BuildRequires:  pkgconfig(sailfishapp)
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  desktop-file-utils

%description
Skoðja giver notifikationer når der er ny aktivitet på GitHub-profiler og repositories.
Kører som baggrundsdaemon og tjekker hvert minut.
Integreret med Sailfish OS lydindstillinger.

%prep
%setup -q -n %{name}-%{version}

%build
%qmake5

%install
rm -rf %{buildroot}
%qmake5_install

desktop-file-install --delete-original \
  --dir %{buildroot}%{_datadir}/applications \
  %{buildroot}%{_datadir}/applications/*.desktop

install -d %{buildroot}%{_datadir}/icons/hicolor/86x86/apps
install -d %{buildroot}%{_datadir}/icons/hicolor/108x108/apps
install -d %{buildroot}%{_datadir}/icons/hicolor/128x128/apps
install -d %{buildroot}%{_datadir}/icons/hicolor/256x256/apps
install -m 644 icons/%{name}-86.png %{buildroot}%{_datadir}/icons/hicolor/86x86/apps/%{name}.png
install -m 644 icons/%{name}-108.png %{buildroot}%{_datadir}/icons/hicolor/108x108/apps/%{name}.png
install -m 644 icons/%{name}-128.png %{buildroot}%{_datadir}/icons/hicolor/128x128/apps/%{name}.png
install -m 644 icons/%{name}-256.png %{buildroot}%{_datadir}/icons/hicolor/256x256/apps/%{name}.png

install -d %{buildroot}%{_datadir}/%{name}
cp -r python %{buildroot}%{_datadir}/%{name}/

install -d %{buildroot}%{_datadir}/%{name}/sounds
install -m 644 sounds/notification.wav %{buildroot}%{_datadir}/%{name}/sounds/notification.wav

install -d %{buildroot}%{_datadir}/lipstick/notificationcategories
install -m 644 config/x-harbour.harbour-skodja.event.conf %{buildroot}%{_datadir}/lipstick/notificationcategories/
install -m 644 config/x-harbour.harbour-skodja.release.conf %{buildroot}%{_datadir}/lipstick/notificationcategories/

install -d %{buildroot}%{_datadir}/%{name}
install -m 755 daemon-wrapper.sh %{buildroot}%{_datadir}/%{name}/daemon-wrapper.sh

install -d %{buildroot}%{_userunitdir}
cat > %{buildroot}%{_userunitdir}/%{name}.service <<'SERVICE'
[Unit]
Description=Skoðja Background Daemon
After=lipstick.service graphical-session.target

[Service]
Type=simple
ExecStart=/usr/share/harbour-skodja/daemon-wrapper.sh 60
Restart=always
RestartSec=5s
TimeoutStartSec=15s
TimeoutStopSec=5s
StandardOutput=journal
StandardError=journal
SyslogIdentifier=harbour-skodja

[Install]
WantedBy=default.target
SERVICE

%post
systemctl --user daemon-reload 2>/dev/null || true
systemctl --user enable harbour-skodja.service 2>/dev/null || true
systemctl --user restart lipstick 2>/dev/null || true
/usr/bin/logger -t harbour-skodja-rpm "%post: daemon-reload and enable done" 2>/dev/null || true

%preun
# Stop the daemon before files are removed (runs as user during uninstall)
systemctl --user stop harbour-skodja.service 2>/dev/null || true

%postun
# Disable autostart and reload (runs as root, commands may fail - that's OK)
systemctl --user disable harbour-skodja.service 2>/dev/null || true
systemctl --user daemon-reload 2>/dev/null || true
systemctl --user restart lipstick 2>/dev/null || true

%files
%defattr(-,root,root,-)
%{_bindir}/%{name}
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/86x86/apps/%{name}.png
%{_datadir}/icons/hicolor/108x108/apps/%{name}.png
%{_datadir}/icons/hicolor/128x128/apps/%{name}.png
%{_datadir}/icons/hicolor/256x256/apps/%{name}.png
%{_userunitdir}/%{name}.service
%{_datadir}/lipstick/notificationcategories/x-harbour.harbour-skodja.event.conf
%{_datadir}/lipstick/notificationcategories/x-harbour.harbour-skodja.release.conf
