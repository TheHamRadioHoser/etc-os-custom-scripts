#!/bin/bash
set -euo pipefail

#Author: Eric Rouse (VA3FYB)

# EDIT THESE
PROGRAM_NAME="hamrs-pro"
URL_BASE="https://hamrs.app/"
APP_DIR="$HOME/Applications/${PROGRAM_NAME}"
APPIMAGE_PATH="${APP_DIR}/${PROGRAM_NAME}.AppImage"
ICON_PATH="$HOME/.local/share/icons/${PROGRAM_NAME}.png"
LOCAL_DESKTOP_FILE="$HOME/.local/share/applications/${PROGRAM_NAME}.desktop"
DESKTOP_FILE="$HOME/Desktop/${PROGRAM_NAME}.desktop"

echo "=== ${PROGRAM_NAME} Installer ==="

mkdir -p "$APP_DIR"
mkdir -p "$HOME/.local/share/icons"
mkdir -p "$HOME/.local/share/applications"
mkdir -p "$HOME/Desktop"

cd "$APP_DIR"
rm -rf squashfs-root

LATEST_URL=$(wget -qO- "$URL_BASE" | grep -oE 'https://hamrs-dist\.s3\.amazonaws\.com/hamrs-pro-[0-9.]+-linux-x86_64\.AppImage' | sort -V | tail -n 1)
[ -n "$LATEST_URL" ] || exit 1

wget -O "${PROGRAM_NAME}.AppImage.tmp" "$LATEST_URL"
chmod +x "${PROGRAM_NAME}.AppImage.tmp"
mv "${PROGRAM_NAME}.AppImage.tmp" "${PROGRAM_NAME}.AppImage"

./"${PROGRAM_NAME}.AppImage" --appimage-extract >/dev/null

cp squashfs-root/hamrs-pro.png "$ICON_PATH"
rm -rf squashfs-root

cat > "$LOCAL_DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=HAMRS Pro
Comment=HAMRS Pro
Exec=$APPIMAGE_PATH --no-sandbox %U
Icon=$ICON_PATH
Terminal=false
Type=Application
Categories=Utility;
EOF

cp "$LOCAL_DESKTOP_FILE" "$DESKTOP_FILE"

chmod +x "$LOCAL_DESKTOP_FILE"
chmod +x "$DESKTOP_FILE"
gio set "$DESKTOP_FILE" metadata::trusted true || true
update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true

echo "Done → run ${PROGRAM_NAME}"
