#!/bin/bash
set -euo pipefail

# Author: Eric Rouse (VA3FYB)

# --- EDIT THESE if adapting for another program ---
PROGRAM_NAME="flrig"
APP_SLUG="${PROGRAM_NAME}"
DISPLAY_NAME="FLRIG"
URL_BASE="https://www.w1hkj.org/files/flrig/"
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

ensure_safe_app_dir() {
    case "$APP_DIR" in
        "$HOME"/Applications/*) return 0 ;;
        *) die "refusing to install outside $HOME/Applications: $APP_DIR" ;;
    esac
}

maybe_switch_ubuntu_2210_to_old_releases() {
    local os_id="" os_codename="" reply="" backup=""

    [ -r /etc/os-release ] || return 0
    os_id="$(sed -n 's/^ID=//p' /etc/os-release | tr -d '"' | head -n 1)"
    os_codename="$(sed -n 's/^VERSION_CODENAME=//p' /etc/os-release | tr -d '"' | head -n 1)"

    [ "$os_id" = "ubuntu" ] || return 0
    [ "$os_codename" = "kinetic" ] || return 0
    grep -Rqs 'old-releases.ubuntu.com/ubuntu' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null && return 0

    echo "Ubuntu 22.10 (kinetic) is EOL, so normal Ubuntu mirrors may fail."
    read -r -p "Switch /etc/apt/sources.list to old-releases.ubuntu.com now? [y/N] " reply || true
    case "$reply" in
        [Yy]|[Yy][Ee][Ss]) ;;
        *) echo "Skipping apt source change. apt may fail if sources are not already fixed."; return 0 ;;
    esac

    [ -f /etc/apt/sources.list ] || die "/etc/apt/sources.list was not found"
    backup="/etc/apt/sources.list.backup-${APP_SLUG}-$(date +%Y%m%d%H%M%S)"
    sudo cp /etc/apt/sources.list "$backup"
    sudo sed -i \
        -e 's|http://[A-Za-z0-9.-]*/ubuntu|http://old-releases.ubuntu.com/ubuntu|g' \
        -e 's|https://[A-Za-z0-9.-]*/ubuntu|http://old-releases.ubuntu.com/ubuntu|g' \
        /etc/apt/sources.list
    echo "Backed up original apt sources to $backup"
}

install_dependencies() {
    echo "Installing build dependencies..."
    maybe_switch_ubuntu_2210_to_old_releases
    sudo apt update
    sudo apt install -y \
        build-essential pkg-config wget ca-certificates \
        libfltk1.3-dev libhamlib-dev libxml2-dev \
        libasound2-dev libpulse-dev libudev-dev
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
        if [ -n "$backup_dir" ]; then
            rm -rf "$backup_dir"
        fi
    else
        if [ -n "$backup_dir" ]; then
            mv "$backup_dir" "$APP_DIR"
        fi
        die "could not replace $APP_DIR"
    fi
}

create_wrapper() {
    cat > "$WRAPPER_PATH" <<EOF
#!/bin/bash
set -e
export HOME="$CONFIG_DIR"
export XDG_CONFIG_HOME="$CONFIG_DIR"
export XDG_DATA_HOME="$DATA_DIR"
mkdir -p "\$HOME" "\$XDG_CONFIG_HOME" "\$XDG_DATA_HOME"
exec "$APP_DIR/bin/${PROGRAM_NAME}" "\$@"
EOF
    chmod +x "$WRAPPER_PATH"
}

create_launcher() {
    local desktop_dir="$1"
    local desktop_file="$desktop_dir/${APP_SLUG}.desktop"
    local icon_path="applications-amateur-radio"

    if [ -f "$APP_DIR/share/pixmaps/${PROGRAM_NAME}.xpm" ]; then
        icon_path="$APP_DIR/share/pixmaps/${PROGRAM_NAME}.xpm"
    elif [ -f "$APP_DIR/share/pixmaps/${PROGRAM_NAME}.png" ]; then
        icon_path="$APP_DIR/share/pixmaps/${PROGRAM_NAME}.png"
    fi

    mkdir -p "$HOME/.local/share/applications" "$desktop_dir"

    cat > "$LOCAL_DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=${DISPLAY_NAME}
Comment=FLRIG transceiver control
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

install_dependencies

echo "Detecting latest version..."
page="$(wget -qO- "$URL_BASE")"
latest_file="$(printf '%s\n' "$page" | grep -oE "${PROGRAM_NAME}-[0-9]+(\.[0-9]+)*\.tar\.gz" | sort -V | tail -n 1 || true)"
[ -n "$latest_file" ] || die "could not detect latest ${PROGRAM_NAME} tarball"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
wget -O "$latest_file" "${URL_BASE}${latest_file}"
tar -xzf "$latest_file"

source_dir="$(find "$BUILD_DIR" -maxdepth 1 -type d -name "${PROGRAM_NAME}-*" | sort -V | tail -n 1 || true)"
[ -n "$source_dir" ] || die "source directory was not found after extraction"

cd "$source_dir"
staging_root="$BUILD_DIR/stage"
rm -rf "$staging_root"

echo "Building ${PROGRAM_NAME}..."
./configure --prefix="$APP_DIR"
make -j"$(nproc)"
make install DESTDIR="$staging_root"

new_app_dir="${staging_root}${APP_DIR}"
[ -x "$new_app_dir/bin/${PROGRAM_NAME}" ] || die "installed binary was not found in staged app directory"

replace_app_dir "$new_app_dir"
create_wrapper
create_launcher "$(get_desktop_dir)"

echo "Done -> run ${DISPLAY_NAME}"
echo "Installed to: $APP_DIR"
echo "Config not touched except this app's own config: $CONFIG_DIR/.flrig"
