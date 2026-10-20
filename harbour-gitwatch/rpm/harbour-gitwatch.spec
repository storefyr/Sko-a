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

Name: harbour-gitwatch
Summary: GitHub Activity Notifier
Version: 0.1.0
Release: 1
Group: Applications/Internet
License: GPL-3.0
URL: https://github.com/storefyr/harbour-gitwatch
Source0: %{name}-%{version}.tar.bz2
BuildArch: noarch

Requires: sailfishsilica-qt5 >= 0.10.9
Requires: pyotherside-qml-plugin-python3-qt5 >= 1.3.0
Requires: python3-base
Requires: python3-requests

%description
Få notifikationer når der er ny aktivitet på GitHub-profiler og repositories.
Tjekker regelmæssigt for nye commits, pull requests, issues og releases.

%prep
%setup -q -n %{name}-%{version}

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}%{_datadir}/%{name}
cp -r qml %{buildroot}%{_datadir}/%{name}/
cp -r python %{buildroot}%{_datadir}/%{name}/
cp -r icons %{buildroot}%{_datadir}/%{name}/

mkdir -p %{buildroot}%{_bindir}
cat > %{buildroot}%{_bindir}/%{name} <<'EOF'
#!/bin/sh
exec /usr/bin/invoker --type=qt5 -s --splash=/usr/share/harbour-gitwatch/icons/harbour-gitwatch.png /usr/bin/sailfish-qml /usr/share/harbour-gitwatch/qml/harbour-gitwatch.qml
EOF
chmod 755 %{buildroot}%{_bindir}/%{name}

mkdir -p %{buildroot}%{_datadir}/applications
cat > %{buildroot}%{_datadir}/applications/%{name}.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=GitWatch
Exec=%{name}
Icon=%{name}
X-Nemo-Application-Type=silica-qt5
EOF

mkdir -p %{buildroot}%{_datadir}/icons/hicolor/86x86/apps
cp icons/%{name}-86.png %{buildroot}%{_datadir}/icons/hicolor/86x86/apps/%{name}.png
mkdir -p %{buildroot}%{_datadir}/icons/hicolor/108x108/apps
cp icons/%{name}-108.png %{buildroot}%{_datadir}/icons/hicolor/108x108/apps/%{name}.png
mkdir -p %{buildroot}%{_datadir}/icons/hicolor/128x128/apps
cp icons/%{name}-128.png %{buildroot}%{_datadir}/icons/hicolor/128x128/apps/%{name}.png
mkdir -p %{buildroot}%{_datadir}/icons/hicolor/256x256/apps
cp icons/%{name}-256.png %{buildroot}%{_datadir}/icons/hicolor/256x256/apps/%{name}.png

mkdir -p %{buildroot}%{_userunitdir}
cat > %{buildroot}%{_userunitdir}/%{name}.service <<'EOF'
[Unit]
Description=GitWatch Background Check

[Service]
Type=oneshot
ExecStart=/usr/bin/sailfish-qml /usr/share/harbour-gitwatch/qml/background-check.qml
EOF

cat > %{buildroot}%{_userunitdir}/%{name}.timer <<'EOF'
[Unit]
Description=GitWatch Periodic Check

[Timer]
OnBootSec=2min
OnUnitActiveSec=30min
AccuracySec=1min
Persistent=true

[Install]
WantedBy=timers.target
EOF

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
%{_datadir}/icons/hicolor/*/apps/%{name}.png
%{_userunitdir}/%{name}.service
%{_userunitdir}/%{name}.timer
