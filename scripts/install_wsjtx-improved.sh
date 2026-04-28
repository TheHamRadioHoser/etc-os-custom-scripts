#!/bin/bash
set -euo pipefail

# Author: Eric Rouse (VA3FYB)

# --- EDIT THESE if adapting for another program ---
PROGRAM_NAME="wsjtx-improved"
APP_SLUG="${PROGRAM_NAME}"
DISPLAY_NAME="WSJT-X Improved"
FILES_URL="https://sourceforge.net/projects/wsjt-x-improved/files/"
USE_SYSTEM_HAMLIB="yes"
HAMLIB_REPO="https://github.com/Hamlib/Hamlib.git"
HAMLIB_BRANCH=""
APP_DIR="$HOME/Applications/${APP_SLUG}"
BUILD_DIR="$HOME/Downloads/${APP_SLUG}_build"
WRAPPER_PATH="$APP_DIR/run-${APP_SLUG}.sh"
LOCAL_DESKTOP_FILE="$HOME/.local/share/applications/${APP_SLUG}.desktop"
CONFIG_DIR="$HOME/.config/${APP_SLUG}"
DATA_DIR="$HOME/.local/share/${APP_SLUG}"
# --------------------------------------------------

VERSION=""
BUILD=""
RELEASE_ID=""
SOURCE_PAGE_URL=""
SOURCE_FILE=""
SOURCE_URL=""
HAMLIB_PREFIX="$BUILD_DIR/hamlib-prefix"
HAMLIB_CMAKE_PREFIX="$HAMLIB_PREFIX"
HAMLIB_SOURCE="built"
ICON_PATH="applications-science"
STAGED_APP_DIR=""

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
        build-essential cmake git gfortran make pkg-config autoconf automake libtool asciidoc \
        qtbase5-dev qtmultimedia5-dev libqt5serialport5-dev libqt5websockets5-dev qttools5-dev qttools5-dev-tools \
        libfftw3-dev libboost-all-dev libreadline-dev libusb-1.0-0-dev libudev-dev libasound2-dev \
        libhamlib-dev ca-certificates curl wget
}

cleanup() {
    rm -rf "$BUILD_DIR"
}

detect_latest_release() {
    local page="" source_page="" latest_dir=""

    echo "Detecting latest WSJT-X Improved source release..."
    page="$(wget -qO- "$FILES_URL")"
    latest_dir="$(printf '%s\n' "$page" | grep -oE 'WSJT-X_v[0-9]+(\.[0-9]+)+' | sort -Vu | tail -n 1 || true)"
    [ -n "$latest_dir" ] || die "could not determine latest WSJT-X Improved version folder"

    VERSION="${latest_dir#WSJT-X_v}"
    SOURCE_PAGE_URL="${FILES_URL}${latest_dir}/Source%20code/"
    source_page="$(wget -qO- "$SOURCE_PAGE_URL")"

    SOURCE_FILE="$(printf '%s\n' "$source_page" \
        | grep -oE "wsjtx-${VERSION}[^\"'[:space:]]*\.tgz" \
        | grep -vE '_AL_|_widescreen_|_qt6' \
        | sort -Vu | tail -n 1 || true)"

    [ -n "$SOURCE_FILE" ] || die "could not determine latest standard Qt5 source tarball for v${VERSION}"

    BUILD="${SOURCE_FILE%.tgz}"
    BUILD="${BUILD##*_PLUS_}"
    RELEASE_ID="${VERSION}-${BUILD}"
    SOURCE_URL="${SOURCE_PAGE_URL}${SOURCE_FILE}/download"

    echo "Latest release detected: ${VERSION} (${BUILD})"
}

use_system_hamlib() {
    [ "$USE_SYSTEM_HAMLIB" = "yes" ] || return 1
    command -v pkg-config >/dev/null 2>&1 || return 1
    pkg-config --exists hamlib 2>/dev/null || return 1

    HAMLIB_CMAKE_PREFIX="$(pkg-config --variable=prefix hamlib 2>/dev/null || true)"
    [ -n "$HAMLIB_CMAKE_PREFIX" ] || HAMLIB_CMAKE_PREFIX="/usr/local"
    HAMLIB_SOURCE="system"
    echo "Using system Hamlib $(pkg-config --modversion hamlib 2>/dev/null) from ${HAMLIB_CMAKE_PREFIX}"
}

build_hamlib() {
    echo "Building Hamlib from source..."
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    rm -rf hamlib-src hamlib-build "$HAMLIB_PREFIX"
    if [ -n "$HAMLIB_BRANCH" ]; then
        git clone --depth 1 --branch "$HAMLIB_BRANCH" "$HAMLIB_REPO" hamlib-src
    else
        git clone --depth 1 "$HAMLIB_REPO" hamlib-src
    fi

    cd "$BUILD_DIR/hamlib-src"
    ./bootstrap

    mkdir -p "$BUILD_DIR/hamlib-build"
    cd "$BUILD_DIR/hamlib-build"

    ../hamlib-src/configure \
        --prefix="$HAMLIB_PREFIX" \
        --disable-shared \
        --enable-static \
        --without-cxx-binding \
        --disable-winradio \
        CFLAGS="-g -O2 -fdata-sections -ffunction-sections" \
        LDFLAGS="-Wl,--gc-sections"

    make -j"$(nproc)"
    make install-strip
}

download_source() {
    echo "Downloading WSJT-X Improved source..."
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    wget -O "$SOURCE_FILE" "$SOURCE_URL"
}

build_and_stage_wsjtx() {
    local staging_root="$BUILD_DIR/stage"
    local staged_app_dir="${staging_root}${APP_DIR}"

    echo "Building WSJT-X Improved..."
    cd "$BUILD_DIR"
    rm -rf wsjtx-src "$staging_root"
    mkdir -p wsjtx-src
    tar -xzf "$SOURCE_FILE" -C wsjtx-src --strip-components=1

    mkdir -p wsjtx-src/build
    cd wsjtx-src/build

    cmake \
        -D CMAKE_BUILD_TYPE=Release \
        -D CMAKE_PREFIX_PATH="$HAMLIB_CMAKE_PREFIX" \
        -D CMAKE_INSTALL_PREFIX="$APP_DIR" \
        -D WSJT_GENERATE_DOCS=OFF \
        -D WSJT_SKIP_MANPAGES=ON \
        -D BUILD_TESTING=OFF \
        ..

    cmake --build . -j"$(nproc)"
    DESTDIR="$staging_root" cmake --install . --prefix "$APP_DIR"

    if [ ! -x "$staged_app_dir/bin/wsjtx" ]; then
        local inner_build_dir="$BUILD_DIR/wsjtx-src/build/wsjtx-prefix/src/wsjtx-build"
        [ -f "$inner_build_dir/cmake_install.cmake" ] || die "inner WSJT-X build install file was not found"

        echo "Top-level install did not stage wsjtx; installing from inner WSJT-X build..."
        DESTDIR="$staging_root" cmake --install "$inner_build_dir" --prefix "$APP_DIR"
    fi

    [ -x "$staged_app_dir/bin/wsjtx" ] || die "staged wsjtx binary was not found"
    [ -x "$staged_app_dir/bin/jt9" ] || die "staged jt9 binary was not found"

    STAGED_APP_DIR="$staged_app_dir"
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
export XDG_CONFIG_HOME="$CONFIG_DIR"
export XDG_DATA_HOME="$DATA_DIR"
export LD_LIBRARY_PATH="$APP_DIR/lib:\${LD_LIBRARY_PATH:-}"
mkdir -p "\$XDG_CONFIG_HOME" "\$XDG_DATA_HOME"
exec "$APP_DIR/bin/wsjtx" "\$@"
EOF
    chmod +x "$WRAPPER_PATH"
}

create_launcher() {
    local desktop_dir="$1"
    local desktop_file="$desktop_dir/${APP_SLUG}.desktop"

    ICON_PATH="$(find "$APP_DIR" -type f \( -iname 'wsjtx*.png' -o -iname 'wsjtx*.svg' -o -iname 'wsjtx*.xpm' \) | head -n 1 || true)"
    [ -n "$ICON_PATH" ] || ICON_PATH="applications-science"

    mkdir -p "$HOME/.local/share/applications" "$desktop_dir"

    cat > "$LOCAL_DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=${DISPLAY_NAME}
Comment=WSJT-X Improved digital modes
Exec="$WRAPPER_PATH" %U
Icon=${ICON_PATH}
Terminal=false
Type=Application
Categories=AudioVideo;Audio;HamRadio;
StartupNotify=true
EOF

    cp "$LOCAL_DESKTOP_FILE" "$desktop_file"
    chmod +x "$LOCAL_DESKTOP_FILE" "$desktop_file"
    gio set "$desktop_file" metadata::trusted true >/dev/null 2>&1 || true
    update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
}

echo "=== ${DISPLAY_NAME} Source Installer ==="

require_command wget
require_command grep
require_command sort
require_command tar
require_command sed
ensure_safe_app_dir
trap cleanup EXIT

detect_latest_release
install_dependencies
if ! use_system_hamlib; then
    build_hamlib
fi
download_source
build_and_stage_wsjtx
replace_app_dir "$STAGED_APP_DIR"
create_wrapper
create_launcher "$(get_desktop_dir)"

echo "Done -> run ${DISPLAY_NAME}"
echo "Release detected: ${RELEASE_ID}"
echo "Hamlib source used: ${HAMLIB_SOURCE}"
echo "Installed to: $APP_DIR"
echo "Config not touched except this app's own config: $CONFIG_DIR"
