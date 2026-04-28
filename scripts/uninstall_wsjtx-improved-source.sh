#!/bin/bash
set -euo pipefail

# Author: Eric Rouse (VA3FYB)

# --- EDIT THESE if adapting for another program ---
PROGRAM_NAME="wsjtx-improved"
BUILD_DIR="$HOME/Downloads/${PROGRAM_NAME}_build"
# --------------------------------------------------

# Find the most recently installed versioned directory (e.g. wsjtx-improved-2.6.1).
# The install script creates one versioned directory per install and removes
# old ones, so under normal use only one should ever exist.
LATEST_APP_DIR=$(find "$HOME/Applications" -maxdepth 1 -mindepth 1 -type d -name "${PROGRAM_NAME}-*" 2>/dev/null | sort -V | tail -n 1 || true)
APP_BASENAME=""
LOCAL_DESKTOP_FILE=""
DESKTOP_FILE=""
CONFIG_DIR=""
DATA_DIR=""

if [ -n "$LATEST_APP_DIR" ]; then
    APP_BASENAME="$(basename "$LATEST_APP_DIR")"
    LOCAL_DESKTOP_FILE="$HOME/.local/share/applications/${APP_BASENAME}.desktop"
    DESKTOP_FILE="$HOME/Desktop/${APP_BASENAME}.desktop"
    CONFIG_DIR="$HOME/.config/${APP_BASENAME}"
    DATA_DIR="$HOME/.local/share/${APP_BASENAME}"
fi

echo "=== ${PROGRAM_NAME} Source Uninstaller ==="

if [ -n "$LATEST_APP_DIR" ]; then
    echo "Removing application files: $LATEST_APP_DIR"
    rm -rf "$LATEST_APP_DIR"

    echo "Removing desktop files..."
    rm -f "$LOCAL_DESKTOP_FILE"
    rm -f "$DESKTOP_FILE"
else
    echo "No installed ${PROGRAM_NAME} source build found in $HOME/Applications."
fi

echo "Removing build and download files..."
rm -rf "$BUILD_DIR"
rm -f "$HOME/Downloads/wsjtx-"*_improved_PLUS_*.tgz

# Tell the desktop environment to re-scan so the removed app disappears
# from the launcher search immediately.
update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true

echo "Done."
if [ -n "$APP_BASENAME" ]; then
    echo "Note: config files in ${CONFIG_DIR} and data files in ${DATA_DIR} are NOT removed."
fi
