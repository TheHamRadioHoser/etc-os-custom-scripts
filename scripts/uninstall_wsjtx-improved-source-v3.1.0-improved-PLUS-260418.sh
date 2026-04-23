#!/bin/bash

#Author: Eric Rouse (VA3FYB)

# EDIT THESE
PROGRAM_NAME="wsjtx-improved"
VERSION="3.1.0"
APP_DIR="$HOME/Applications/${PROGRAM_NAME}-${VERSION}"
WRAPPER_PATH="${APP_DIR}/run-${PROGRAM_NAME}.sh"
LOCAL_DESKTOP_FILE="$HOME/.local/share/applications/${PROGRAM_NAME}-${VERSION}.desktop"
DESKTOP_FILE="$HOME/Desktop/${PROGRAM_NAME}-${VERSION}.desktop"
BUILD_DIR="$HOME/Downloads/${PROGRAM_NAME}_build"

CONFIG_DIR="$HOME/.config/${PROGRAM_NAME}-${VERSION}"
DATA_DIR="$HOME/.local/share/${PROGRAM_NAME}-${VERSION}"

echo "=== ${PROGRAM_NAME} Source Uninstaller ==="

echo "Removing application files..."
rm -rf "$APP_DIR"

echo "Removing desktop files..."
rm -f "$LOCAL_DESKTOP_FILE"
rm -f "$DESKTOP_FILE"

echo "Removing build and download files..."
rm -rf "$BUILD_DIR"
rm -f "$HOME/Downloads/wsjtx-"*_improved_PLUS_*.tgz

echo "Done."
echo "Note: config files in ${CONFIG_DIR} and data files in ${DATA_DIR} are NOT removed."
