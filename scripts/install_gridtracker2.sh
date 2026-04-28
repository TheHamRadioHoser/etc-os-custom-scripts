#!/bin/bash
set -euo pipefail

# Author: Eric Rouse (VA3FYB)

# --- EDIT THESE if adapting for another program ---
PROGRAM_NAME="gridtracker2"
UPSTREAM_NAME="GridTracker2"
APP_SLUG="${PROGRAM_NAME}"
DISPLAY_NAME="GridTracker2"
URL_BASE="https://gridtracker.org/index.php/downloads/gridtracker-downloads"
APP_DIR="$HOME/Applications/${APP_SLUG}"
BUILD_DIR="$HOME/Downloads/${APP_SLUG}_build"
WRAPPER_PATH="$APP_DIR/run-${APP_SLUG}.sh"
LOCAL_DESKTOP_FILE="$HOME/.local/share/applications/${APP_SLUG}.desktop"
CONFIG_DIR="$HOME/.config/${APP_SLUG}"
DATA_DIR="$HOME/.local/share/${APP_SLUG}"
# --------------------------------------------------

die() {
    echo "Error: $*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "required command '$1' not found"
}

get_desktop_dir() {
    local desktop_dir=""
    if command -v xdg-user-dir >/dev/null 2>&1; then
        desktop_dir="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
    fi
    [ -n "$desktop_dir" ] || desktop_dir="$HOME/Desktop"
    printf '%s\n' "$desktop_dir"
}

detect_gridtracker_arch() {
    case "$(uname -m)" in
        x86_64|amd64) printf '%s\n' "x64" ;;
        aarch64|arm64) printf '%s\n' "arm64" ;;
        armv7l|armv7*) printf '%s\n' "armv7l" ;;
        *) die "unsupported CPU architecture: $(uname -m)" ;;
    esac
}

ensure_safe_app_dir() {
    case "$APP_DIR" in
        "$HOME"/Applications/*) return 0 ;;
        *) die "refusing to install outside $HOME/Applications: $APP_DIR" ;;
    esac
}

cleanup() {
    rm -rf "$BUILD_DIR"
}

replace_app_dir() {
    local new_dir="$1"
    local backup_dir=""

    ensure_safe_app_dir
    [ -d "$new_dir" ] || die "staged app directory was not created: $new_dir"
    mkdir -p "$(dirname "$APP_DIR")"

    if [ -e "$APP_DIR" ]; then
        backup_dir="${APP_DIR}.previous.$$"
        rm -rf "$backup_dir"
        mv "$APP_DIR" "$backup_dir"
    fi

    if mv "$new_dir" "$APP_DIR"; then
        [ -n "$backup_dir" ] && rm -rf "$backup_dir"
    else
        [ -n "$backup_dir" ] && mv "$backup_dir" "$APP_DIR"
        die "could not replace $APP_DIR"
    fi
}

prepare_new_app_dir() {
    local extract_dir="$1"
    local new_dir="$2"
    local top_count=""
    local top_item=""

    top_count="$(find "$extract_dir" -mindepth 1 -maxdepth 1 | wc -l)"
    if [ "$top_count" -eq 1 ]; then
        top_item="$(find "$extract_dir" -mindepth 1 -maxdepth 1 | head -n 1)"
        if [ -d "$top_item" ]; then
            mv "$top_item" "$new_dir"
            return 0
        fi
    fi

    mkdir -p "$new_dir"
    cp -a "$extract_dir"/. "$new_dir"/
}

create_wrapper() {
    cat > "$WRAPPER_PATH" <<EOF
#!/bin/bash
set -e
APP_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
export XDG_CONFIG_HOME="$CONFIG_DIR"
export XDG_DATA_HOME="$DATA_DIR"
mkdir -p "\$XDG_CONFIG_HOME" "\$XDG_DATA_HOME"
cd "\$APP_DIR"
for candidate in "\$APP_DIR/GridTracker2" "\$APP_DIR/gridtracker2" "\$APP_DIR/GridTracker" "\$APP_DIR/gridtracker"; do
    if [ -x "\$candidate" ]; then
        exec "\$candidate" "\$@"
    fi
done
echo "Error: GridTracker2 executable was not found in \$APP_DIR" >&2
exit 1
EOF
    chmod +x "$WRAPPER_PATH"
}

create_launcher() {
    local desktop_dir="$1"
    local desktop_file="$desktop_dir/${APP_SLUG}.desktop"
    local icon_path=""

    icon_path="$(find "$APP_DIR" -type f \( -iname '*gridtracker*.png' -o -iname '*gridtracker*.svg' -o -iname '*gridtracker*.xpm' \) | head -n 1 || true)"
    [ -n "$icon_path" ] || icon_path="applications-internet"

    mkdir -p "$HOME/.local/share/applications" "$desktop_dir"

    cat > "$LOCAL_DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=${DISPLAY_NAME}
Comment=Amateur radio mapping and logging companion
Exec="$WRAPPER_PATH" %U
Icon=${icon_path}
Terminal=false
Type=Application
Categories=HamRadio;Utility;
StartupNotify=true
EOF

    cp "$LOCAL_DESKTOP_FILE" "$desktop_file"
    chmod +x "$LOCAL_DESKTOP_FILE" "$desktop_file"
    gio set "$desktop_file" metadata::trusted true >/dev/null 2>&1 || true
    update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
}

echo "=== ${DISPLAY_NAME} Installer ==="

require_command wget
require_command grep
require_command sort
require_command tar
ensure_safe_app_dir
trap cleanup EXIT

archive_arch="$(detect_gridtracker_arch)"

echo "Detecting latest version..."
page="$(wget -qO- "$URL_BASE")"
latest_url="$(printf '%s\n' "$page" | grep -oE "https://download2\.gridtracker\.org/${UPSTREAM_NAME}-[0-9]+(\.[0-9]+)*-${archive_arch}\.tar\.gz" | sort -V | tail -n 1 || true)"
[ -n "$latest_url" ] || die "could not detect latest ${UPSTREAM_NAME} tar.gz URL for ${archive_arch}"

mkdir -p "$BUILD_DIR/extract"
cd "$BUILD_DIR"
wget -O "${PROGRAM_NAME}.tar.gz" "$latest_url"
tar -xzf "${PROGRAM_NAME}.tar.gz" -C "$BUILD_DIR/extract"

new_app_dir="$BUILD_DIR/new-app"
rm -rf "$new_app_dir"
prepare_new_app_dir "$BUILD_DIR/extract" "$new_app_dir"

if ! find "$new_app_dir" -maxdepth 1 -type f \( -name 'GridTracker2' -o -name 'gridtracker2' -o -name 'GridTracker' -o -name 'gridtracker' \) -perm -u+x | grep -q .; then
    die "GridTracker2 executable was not found in extracted tarball"
fi

replace_app_dir "$new_app_dir"
create_wrapper
create_launcher "$(get_desktop_dir)"

echo "Done -> run ${DISPLAY_NAME}"
echo "Installed to: $APP_DIR"
echo "Config not touched except this app's own config: $CONFIG_DIR"
