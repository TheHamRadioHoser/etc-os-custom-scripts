#!/bin/bash
set -euo pipefail

# Author: Eric Rouse (VA3FYB)

# --- EDIT THESE if adapting for another program ---
PROGRAM_NAME="hamrs-pro"
APP_DIR="$HOME/Applications/${PROGRAM_NAME}"
# --------------------------------------------------

echo "=== ${PROGRAM_NAME} Uninstaller ==="

# Remove the entire application directory — this contains the AppImage itself.
echo "Removing application files..."
rm -rf "$APP_DIR"

echo "Removing desktop files..."
rm -f "$HOME/.local/share/applications/${PROGRAM_NAME}.desktop"
rm -f "$HOME/Desktop/${PROGRAM_NAME}.desktop"

echo "Removing icon..."
rm -f "$HOME/.local/share/icons/${PROGRAM_NAME}.png"

echo "Removing leftover downloads..."
rm -f "$HOME/Downloads/${PROGRAM_NAME}-"*.AppImage

# Tell the desktop environment to re-scan so the removed app disappears
# from the launcher search immediately.
update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true

echo "Done."
