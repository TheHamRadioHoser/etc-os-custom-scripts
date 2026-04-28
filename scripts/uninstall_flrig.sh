#!/bin/bash
set -euo pipefail

# Author: Eric Rouse (VA3FYB)

# --- EDIT THESE if adapting for another program ---
PROGRAM_NAME="flrig"
APP_DIR="$HOME/Applications/${PROGRAM_NAME}"
# --------------------------------------------------

echo "=== ${PROGRAM_NAME} Uninstaller ==="

# Remove the entire application directory that was created by the installer.
# Because the installer used --prefix=$APP_DIR, everything (binary, data files,
# man pages, icons) lives here — one folder to remove covers it all.
echo "Removing application files..."
rm -rf "$APP_DIR"

echo "Removing desktop files..."
rm -f "$HOME/.local/share/applications/${PROGRAM_NAME}.desktop"
rm -f "$HOME/Desktop/${PROGRAM_NAME}.desktop"

echo "Removing leftover build/download files..."
rm -rf "$HOME/Downloads/${PROGRAM_NAME}_build"
rm -f "$HOME/Downloads/${PROGRAM_NAME}-"*.tar.gz

# Tell the desktop environment to re-scan so the removed app disappears
# from the launcher search immediately.
update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true

echo "Done."
echo "Note: config files in $HOME/.${PROGRAM_NAME} are NOT removed."
