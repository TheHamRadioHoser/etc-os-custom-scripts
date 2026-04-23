#!/bin/bash
set -euo pipefail

#Author: Eric Rouse (VA3FYB)

# EDIT THESE
PROGRAM_NAME="GridTracker2"
URL_BASE="https://gridtracker.org/index.php/downloads/gridtracker-downloads"

echo "=== ${PROGRAM_NAME} Installer ==="

mkdir -p ~/Downloads/${PROGRAM_NAME}_build
cd ~/Downloads/${PROGRAM_NAME}_build
rm -f ${PROGRAM_NAME}-*.deb

LATEST_URL=$(wget -qO- "$URL_BASE" | grep -oE 'https://download2\.gridtracker\.org/GridTracker2-[0-9.]+-amd64\.deb' | sort -V | tail -n 1)
[ -n "$LATEST_URL" ] || exit 1

wget "$LATEST_URL"
sudo apt install -y ./${PROGRAM_NAME}-*.deb

rm -rf ~/Downloads/${PROGRAM_NAME}_build

echo "Done → run gridtracker2"
