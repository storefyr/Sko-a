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
Version:        0.1.0
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
Tjekker regelmæssigt for nye commits, pull requests, issues og releases.
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

install -d %{buildroot}%{_userunitdir}
cat > %{buildroot}%{_userunitdir}/%{name}.service <<'SERVICE'
[Unit]
Description=GitWatch Background Check
After=lipstick.service

[Service]
Type=oneshot
ExecStart=/usr/bin/sailjail -p harbour-gitwatch.desktop /usr/bin/invoker --type=qt5 -s /usr/bin/sailfish-qml /usr/share/harbour-gitwatch/qml/background-check.qml
SERVICE

cat > %{buildroot}%{_userunitdir}/%{name}.timer <<'TIMER'
[Unit]
Description=GitWatch Periodic Check

[Timer]
OnBootSec=2min
OnUnitActiveSec=30min
AccuracySec=1min
Persistent=true

[Install]
WantedBy=timers.target
TIMER

%post
systemctl --user daemon-reload || true
systemctl --user enable harbour-gitwatch.timer || true
systemctl --user start harbour-gitwatch.timer || true

%postun
systemctl --user stop harbour-gitwatch.timer || true
systemctl --user disable harbour-gitwatch.timer || true
systemctl --user daemon-reload || true

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
%{_userunitdir}/%{name}.timer
