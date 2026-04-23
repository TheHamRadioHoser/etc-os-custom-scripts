#!/bin/bash

#Author: Eric Rouse (VA3FYB)

# EDIT THESE
PROGRAM_NAME="hamrs-pro"
APP_DIR="$HOME/Applications/${PROGRAM_NAME}"

echo "=== ${PROGRAM_NAME} Uninstaller ==="

echo "Removing application files..."
rm -rf "$APP_DIR"

echo "Removing desktop files..."
rm -f "$HOME/.local/share/applications/${PROGRAM_NAME}.desktop"
rm -f "$HOME/Desktop/${PROGRAM_NAME}.desktop"

echo "Removing icon..."
rm -f "$HOME/.local/share/icons/${PROGRAM_NAME}.png"

echo "Removing leftover downloads..."
rm -f "$HOME/Downloads/${PROGRAM_NAME}-"*.AppImage

if [ -d "$HOME/Downloads/squashfs-root" ]; then
    if [ -f "$HOME/Downloads/squashfs-root/hamrs-pro.desktop" ] || \
       [ -f "$HOME/Downloads/squashfs-root/hamrs-pro" ] || \
       [ -f "$HOME/Downloads/squashfs-root/hamrs-pro.png" ]; then
        rm -rf "$HOME/Downloads/squashfs-root"
    fi
fi

echo "Done."
