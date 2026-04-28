#!/bin/bash
set -euo pipefail

# Author: Eric Rouse (VA3FYB)

# --- EDIT THESE if adapting for another program ---
PROGRAM_NAME="hamrs-pro"
URL_BASE="https://hamrs.app/"
APP_DIR="$HOME/Applications/${PROGRAM_NAME}"
APPIMAGE_PATH="${APP_DIR}/${PROGRAM_NAME}.AppImage"
ICON_PATH="$HOME/.local/share/icons/${PROGRAM_NAME}.png"
LOCAL_DESKTOP_FILE="$HOME/.local/share/applications/${PROGRAM_NAME}.desktop"
DESKTOP_FILE="$HOME/Desktop/${PROGRAM_NAME}.desktop"
# --------------------------------------------------

echo "=== ${PROGRAM_NAME} Installer ==="

mkdir -p "$APP_DIR"
mkdir -p "$HOME/.local/share/icons"
mkdir -p "$HOME/.local/share/applications"
mkdir -p "$HOME/Desktop"

cd "$APP_DIR"
# Remove any leftover extracted AppImage contents from a previous install.
rm -rf squashfs-root

# Fetch the HAMRS homepage and extract the direct AppImage download URL,
# then take the highest version with sort -V.
echo "Detecting latest version..."
LATEST_URL=$(wget -qO- "$URL_BASE" | grep -oE 'https://hamrs-dist\.s3\.amazonaws\.com/hamrs-pro-[0-9.]+-linux-x86_64\.AppImage' | sort -V | tail -n 1)
[ -n "$LATEST_URL" ] || { echo "Error: could not detect latest version URL."; exit 1; }

wget -O "${PROGRAM_NAME}.AppImage.tmp" "$LATEST_URL"
chmod +x "${PROGRAM_NAME}.AppImage.tmp"
mv "${PROGRAM_NAME}.AppImage.tmp" "${PROGRAM_NAME}.AppImage"

# Extract the AppImage temporarily just to pull out the bundled icon,
# then delete the extracted folder — the AppImage itself is what runs.
./"${PROGRAM_NAME}.AppImage" --appimage-extract >/dev/null
cp squashfs-root/hamrs-pro.png "$ICON_PATH"
rm -rf squashfs-root

# Write the .desktop file. This is what makes the app appear in the
# application launcher search and on the desktop.
#
# Note on --no-sandbox: HAMRS Pro is an Electron app (Chromium-based).
# Some Linux environments require this flag to launch Electron apps.
# If you find HAMRS Pro launches fine without it, you can remove that flag
# from the Exec line below.
cat > "$LOCAL_DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=HAMRS Pro
Comment=HAMRS Pro
Exec=$APPIMAGE_PATH --no-sandbox %U
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

echo "Done → run ${PROGRAM_NAME}"
