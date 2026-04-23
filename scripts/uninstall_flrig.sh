#!/bin/bash

#Author: Eric Rouse (VA3FYB)

# EDIT THESE
PROGRAM_NAME="flrig"

echo "=== ${PROGRAM_NAME} Uninstaller ==="

echo "Removing binaries..."
sudo rm -f /usr/local/bin/${PROGRAM_NAME}

echo "Removing desktop files..."
sudo rm -f /usr/local/share/applications/${PROGRAM_NAME}.desktop
rm -f ~/Desktop/${PROGRAM_NAME}.desktop

echo "Removing icon..."
sudo rm -f /usr/local/share/pixmaps/${PROGRAM_NAME}.xpm

echo "Removing build and download files..."
rm -rf ~/Downloads/${PROGRAM_NAME}_build
rm -rf ~/Downloads/${PROGRAM_NAME}-*
rm -f ~/Downloads/${PROGRAM_NAME}-*.tar.gz

echo "Done."
echo "Note: config files in ~/.${PROGRAM_NAME} are NOT removed."
