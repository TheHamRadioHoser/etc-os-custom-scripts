#!/bin/bash
set -euo pipefail

# Author: Eric Rouse (VA3FYB)

# --- EDIT THESE if adapting for another program ---
PROGRAM_NAME="flrig"
URL_BASE="https://www.w1hkj.org/files/flrig/"
APP_DIR="$HOME/Applications/${PROGRAM_NAME}"
LOCAL_DESKTOP_FILE="$HOME/.local/share/applications/${PROGRAM_NAME}.desktop"
DESKTOP_FILE="$HOME/Desktop/${PROGRAM_NAME}.desktop"
BUILD_DIR="$HOME/Downloads/${PROGRAM_NAME}_build"
# --------------------------------------------------

echo "=== ${PROGRAM_NAME} Installer ==="

# Install the packages needed to compile flrig from source.
# These are development libraries (headers + compilers) - not the same as
# the runtime packages an end-user would install via apt.
echo "Installing build dependencies..."
sudo apt update
sudo apt install -y \
    build-essential pkg-config \
    libfltk1.3-dev libhamlib-dev libxml2-dev \
    libasound2-dev libpulse-dev libudev-dev

# Fetch the directory listing from the upstream site and pull out the
# highest version number tarball using sort -V (version-aware sort).
echo "Detecting latest version..."
LATEST=$(wget -qO- "$URL_BASE" | grep -oE "${PROGRAM_NAME}-[0-9.]+\.tar\.gz" | sort -V | tail -n 1)
[ -n "$LATEST" ] || { echo "Error: could not detect latest version."; exit 1; }

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
rm -rf ${PROGRAM_NAME}-*

wget "${URL_BASE}${LATEST}"
tar -xvf "$LATEST"

cd ${PROGRAM_NAME}-*/

# --prefix tells the build system to install everything under ~/Applications/flrig/
# instead of the system-wide /usr/local. This keeps it fully parallel to any
# version that may be pre-installed on your OS, and means no sudo is needed
# for the install step.
./configure --prefix="$APP_DIR"
make
make install

# Create the directories for the desktop launcher files.
mkdir -p "$HOME/.local/share/applications"
mkdir -p "$HOME/Desktop"

# Find an icon that was installed with the program. Fall back to a generic
# system icon name if none is found.
ICON_PATH=""
if [ -f "$APP_DIR/share/pixmaps/${PROGRAM_NAME}.xpm" ]; then
    ICON_PATH="$APP_DIR/share/pixmaps/${PROGRAM_NAME}.xpm"
elif [ -f "$APP_DIR/share/pixmaps/${PROGRAM_NAME}.png" ]; then
    ICON_PATH="$APP_DIR/share/pixmaps/${PROGRAM_NAME}.png"
else
    ICON_PATH="applications-amateur-radio"
fi

# Write the .desktop file. This is what makes the app appear in the
# application launcher search and on the desktop.
cat > "$LOCAL_DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=FLRIG
Comment=FLRIG Transceiver Control
Exec=$APP_DIR/bin/${PROGRAM_NAME}
Icon=$ICON_PATH
Terminal=false
Type=Application
Categories=HamRadio;Utility;
EOF

cp "$LOCAL_DESKTOP_FILE" "$DESKTOP_FILE"
chmod +x "$LOCAL_DESKTOP_FILE"
chmod +x "$DESKTOP_FILE"
gio set "$DESKTOP_FILE" metadata::trusted true >/dev/null 2>&1 || true

# Tell the desktop environment to re-scan for new/changed .desktop files
# so the app shows up in the launcher search immediately.
update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true

# Remove all the source code and intermediate build files — they are no
# longer needed once the program is installed.
rm -rf "$BUILD_DIR"

echo "Done → run ${PROGRAM_NAME}"
