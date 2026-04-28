#!/bin/bash
set -euo pipefail

# Author: Eric Rouse (VA3FYB)

# --- EDIT THESE if adapting for another program ---
PROGRAM_NAME="gridtracker2"
APP_SLUG="${PROGRAM_NAME}"
DISPLAY_NAME="GridTracker2"
APP_DIR="$HOME/Applications/${APP_SLUG}"
BUILD_DIR="$HOME/Downloads/${APP_SLUG}_build"
LOCAL_DESKTOP_FILE="$HOME/.local/share/applications/${APP_SLUG}.desktop"
CONFIG_DIR="$HOME/.config/${APP_SLUG}"
DATA_DIR="$HOME/.local/share/${APP_SLUG}"
# --------------------------------------------------

die() {
    echo "Error: $*" >&2
    exit 1
}

get_desktop_dir() {
    local desktop_dir=""
    if command -v xdg-user-dir >/dev/null 2>&1; then
        desktop_dir="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
    fi
    [ -n "$desktop_dir" ] || desktop_dir="$HOME/Desktop"
    printf '%s\n' "$desktop_dir"
}

ensure_safe_app_dir() {
    case "$APP_DIR" in
        "$HOME"/Applications/*) return 0 ;;
        *) die "refusing to remove outside $HOME/Applications: $APP_DIR" ;;
    esac
}

echo "=== ${DISPLAY_NAME} Uninstaller ==="

ensure_safe_app_dir
desktop_dir="$(get_desktop_dir)"

echo "Removing application files..."
rm -rf "$APP_DIR"

echo "Removing desktop files..."
rm -f "$LOCAL_DESKTOP_FILE"
rm -f "$desktop_dir/${APP_SLUG}.desktop"

echo "Removing leftover build/download files..."
rm -rf "$BUILD_DIR"

update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true

echo "Done."
echo "Config not removed: $CONFIG_DIR"
echo "Data not removed: $DATA_DIR"
