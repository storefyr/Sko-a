#!/bin/bash
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
set -e

APP_NAME="harbour-gitwatch"
VERSION="0.1.0"
PACKAGE_NAME="${APP_NAME}-${VERSION}"

cd "$(dirname "$0")"

echo "Building ${PACKAGE_NAME}..."

rm -rf "${PACKAGE_NAME}"
mkdir -p "${PACKAGE_NAME}"

cp -r qml "${PACKAGE_NAME}/"
cp -r python "${PACKAGE_NAME}/"
cp -r icons "${PACKAGE_NAME}/"
cp -r rpm "${PACKAGE_NAME}/"
cp README.md "${PACKAGE_NAME}/"
cp build.sh "${PACKAGE_NAME}/"

find "${PACKAGE_NAME}" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
find "${PACKAGE_NAME}" -name "*.pyc" -delete 2>/dev/null || true

tar -cjf "${PACKAGE_NAME}.tar.bz2" "${PACKAGE_NAME}"

echo "Created ${PACKAGE_NAME}.tar.bz2"
echo ""
echo "To build RPM, run:"
echo "  sb2 -t SailfishOS-latest-aarch64 -R rpmbuild -ta ${PACKAGE_NAME}.tar.bz2"
