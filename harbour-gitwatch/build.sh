#!/bin/bash
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
