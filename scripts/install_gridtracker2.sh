#!/bin/bash
set -euo pipefail

# Author: Eric Rouse (VA3FYB)

# --- EDIT THESE if adapting for another program ---
PROGRAM_NAME="GridTracker2"
URL_BASE="https://gridtracker.org/index.php/downloads/gridtracker-downloads"
BUILD_DIR="$HOME/Downloads/${PROGRAM_NAME}_build"
# --------------------------------------------------

echo "=== ${PROGRAM_NAME} Installer ==="

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
rm -f ${PROGRAM_NAME}-*.deb

# Fetch the GridTracker downloads page and extract the direct .deb download
# URL, then take the highest version with sort -V.
echo "Detecting latest version..."
LATEST_URL=$(wget -qO- "$URL_BASE" | grep -oE 'https://download2\.gridtracker\.org/GridTracker2-[0-9.]+-amd64\.deb' | sort -V | tail -n 1)
[ -n "$LATEST_URL" ] || { echo "Error: could not detect latest version URL."; exit 1; }

wget "$LATEST_URL"

# apt update is required here because installing a .deb via "apt install"
# still resolves and downloads any dependencies from your apt sources.
# On EOL Ubuntu (such as 22.10), if your apt sources are not already pointing
# at old-releases.ubuntu.com this step may fail. If that happens, the
# install_wsjtx-improved-source.sh script contains a switch_to_old_releases()
# function that fixes this — run that script first to repair your apt sources.
echo "Updating apt sources and installing..."
sudo apt update
sudo apt install -y ./${PROGRAM_NAME}-*.deb

rm -rf "$BUILD_DIR"

echo "Done → run gridtracker2"
