#!/bin/bash
set -euo pipefail

#Author: Eric Rouse (VA3FYB)

# EDIT THESE
PROGRAM_NAME="flrig"
URL_BASE="https://www.w1hkj.org/files/flrig/"

echo "=== ${PROGRAM_NAME} Installer ==="

mkdir -p ~/Downloads/${PROGRAM_NAME}_build
cd ~/Downloads/${PROGRAM_NAME}_build
rm -rf ${PROGRAM_NAME}-*

LATEST=$(wget -qO- "$URL_BASE" | grep -oE "${PROGRAM_NAME}-[0-9.]+\.tar\.gz" | sort -V | tail -n 1)
[ -n "$LATEST" ] || exit 1

wget "${URL_BASE}${LATEST}"
tar -xvf "$LATEST"

cd ${PROGRAM_NAME}-*/ || exit 1

./configure
make
sudo make install

if [ -f /usr/local/share/applications/${PROGRAM_NAME}.desktop ]; then
    cp /usr/local/share/applications/${PROGRAM_NAME}.desktop ~/Desktop/${PROGRAM_NAME}.desktop
    chmod +x ~/Desktop/${PROGRAM_NAME}.desktop
    gio set ~/Desktop/${PROGRAM_NAME}.desktop metadata::trusted true || true
fi

rm -rf ~/Downloads/${PROGRAM_NAME}_build

echo "Done → run ${PROGRAM_NAME}"
