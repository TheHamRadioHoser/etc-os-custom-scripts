#!/bin/bash

#Author: Eric Rouse (VA3FYB)

# EDIT THESE
PROGRAM_NAME="gridtracker2"

echo "=== ${PROGRAM_NAME} Uninstaller ==="

sudo apt remove -y ${PROGRAM_NAME}

echo "Removing build and download files..."
rm -rf ~/Downloads/${PROGRAM_NAME}_build
rm -f ~/Downloads/${PROGRAM_NAME}-*.deb

echo "Done."
