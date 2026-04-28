#!/bin/bash
set -euo pipefail

# Author: Eric Rouse (VA3FYB)

# --- EDIT THESE if adapting for another program ---
PROGRAM_NAME="gridtracker2"
# --------------------------------------------------

echo "=== ${PROGRAM_NAME} Uninstaller ==="

# GridTracker2 was installed as a .deb package via apt, so apt remove is
# the correct way to fully uninstall it — it tracks every file that was
# installed and removes them all cleanly.
sudo apt remove -y ${PROGRAM_NAME}

echo "Removing leftover build/download files..."
rm -rf "$HOME/Downloads/${PROGRAM_NAME}_build"
rm -f "$HOME/Downloads/${PROGRAM_NAME}-"*.deb

echo "Done."
