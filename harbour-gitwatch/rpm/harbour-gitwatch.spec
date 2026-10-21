# harbour-gitwatch - GitHub Activity Notifier for Sailfish OS
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

Name:           harbour-gitwatch
Summary:        GitHub Activity Notifier
Version:        0.4.1
Release:        1
Group:          Applications/Internet
License:        GPL-3.0
URL:            https://github.com/storefyr/Sko-a/tree/main/harbour-gitwatch
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
Få notifikationer når der er ny aktivitet på GitHub-profiler og repositories.
Baggrundstjek hvert minut via systemd timer. Integreret med Sailfish OS lydindstillinger.
Kører baggrundstjek hver 30. minut via systemd timer.

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
install -m 644 config/x-harbour.harbour-gitwatch.event.conf %{buildroot}%{_datadir}/lipstick/notificationcategories/
install -m 644 config/x-harbour.harbour-gitwatch.release.conf %{buildroot}%{_datadir}/lipstick/notificationcategories/

install -d %{buildroot}%{_userunitdir}
cat > %{buildroot}%{_userunitdir}/%{name}.service <<'SERVICE'
[Unit]
Description=GitWatch Background Daemon
After=lipstick.service graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/sailjail -p harbour-gitwatch.desktop /usr/bin/invoker --type=qt5 -s /usr/bin/sailfish-qml /usr/share/harbour-gitwatch/qml/gitwatch-daemon.qml
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=default.target
SERVICE

%post
systemctl --user daemon-reload || true
systemctl --user enable harbour-gitwatch.service || true
systemctl --user restart harbour-gitwatch.service || true
systemctl --user restart lipstick || true

%postun
systemctl --user stop harbour-gitwatch.service || true
systemctl --user disable harbour-gitwatch.service || true
systemctl --user daemon-reload || true
systemctl --user restart lipstick || true

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
%{_datadir}/lipstick/notificationcategories/x-harbour.harbour-gitwatch.event.conf
%{_datadir}/lipstick/notificationcategories/x-harbour.harbour-gitwatch.release.conf
