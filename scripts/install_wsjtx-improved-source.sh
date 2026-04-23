#!/bin/bash
set -euo pipefail

#Author: Eric Rouse (VA3FYB)

# EDIT THESE
PROGRAM_NAME="wsjtx-improved"
FILES_URL="https://sourceforge.net/projects/wsjt-x-improved/files/"
USE_SYSTEM_HAMLIB="yes"
HAMLIB_REPO="https://github.com/Hamlib/Hamlib.git"
HAMLIB_BRANCH="integration"

VERSION=""
BUILD=""
RELEASE_ID=""
SOURCE_PAGE_URL=""
SOURCE_FILE=""
SOURCE_URL=""
APP_DIR=""
APP_BIN_DIR=""
WRAPPER_PATH=""
ICON_FILE=""
LOCAL_DESKTOP_FILE=""
DESKTOP_FILE=""
CONFIG_DIR=""
DATA_DIR=""

BUILD_DIR="$HOME/Downloads/${PROGRAM_NAME}_build"
HAMLIB_PREFIX="$BUILD_DIR/hamlib-prefix"

TARGET_BIN=""
ICON_PATH=""
HAMLIB_SOURCE="built"
HAMLIB_CMAKE_PREFIX="$HAMLIB_PREFIX"
INSTALL_MODE="packaged-from-build"

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Error: required command '$1' not found."
        exit 1
    }
}

detect_latest_release() {
    local page latest_dir source_page

    echo "Detecting latest WSJT-X Improved source release..."
    page=$(wget -qO- "$FILES_URL")

    latest_dir=$(printf '%s\n' "$page" | grep -oE 'WSJT-X_v[0-9]+(\.[0-9]+)+' | sort -Vu | tail -n 1)
    [ -n "$latest_dir" ] || {
        echo "Error: could not determine latest WSJT-X Improved version folder."
        exit 1
    }

    VERSION="${latest_dir#WSJT-X_v}"
    SOURCE_PAGE_URL="${FILES_URL}${latest_dir}/Source%20code/"
    source_page=$(wget -qO- "$SOURCE_PAGE_URL")

    SOURCE_FILE=$(printf '%s\n' "$source_page" \
        | grep -oE "wsjtx-${VERSION}[^\"'[:space:]]*\.tgz" \
        | grep -vE '_AL_|_widescreen_|_qt6' \
        | sort -Vu | tail -n 1)

    [ -n "$SOURCE_FILE" ] || {
        echo "Error: could not determine latest standard Qt5 source tarball for v${VERSION}."
        exit 1
    }

    BUILD="${SOURCE_FILE%.tgz}"
    BUILD="${BUILD##*_PLUS_}"
    RELEASE_ID="${VERSION}-${BUILD}"
    SOURCE_URL="${SOURCE_PAGE_URL}${SOURCE_FILE}/download"

    APP_DIR="$HOME/Applications/${PROGRAM_NAME}-${VERSION}"
    APP_BIN_DIR="${APP_DIR}/bin"
    WRAPPER_PATH="${APP_DIR}/run-${PROGRAM_NAME}.sh"
    ICON_FILE="${APP_DIR}/${PROGRAM_NAME}.png"
    LOCAL_DESKTOP_FILE="$HOME/.local/share/applications/${PROGRAM_NAME}-${VERSION}.desktop"
    DESKTOP_FILE="$HOME/Desktop/${PROGRAM_NAME}-${VERSION}.desktop"
    CONFIG_DIR="$HOME/.config/${PROGRAM_NAME}-${VERSION}"
    DATA_DIR="$HOME/.local/share/${PROGRAM_NAME}-${VERSION}"

    echo "Latest release detected: ${VERSION} (${BUILD})"
}

switch_to_old_releases() {
    if ! grep -q '^ID=ubuntu' /etc/os-release 2>/dev/null; then
        return 0
    fi

    if grep -q 'old-releases.ubuntu.com' /etc/apt/sources.list 2>/dev/null; then
        return 0
    fi

    echo "Switching apt sources to old-releases..."
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup-${PROGRAM_NAME}-$(date +%Y%m%d%H%M%S)
    sudo sed -i \
        -e 's|http://[A-Za-z0-9.-]*/ubuntu|http://old-releases.ubuntu.com/ubuntu|g' \
        -e 's|https://[A-Za-z0-9.-]*/ubuntu|http://old-releases.ubuntu.com/ubuntu|g' \
        /etc/apt/sources.list
}

install_dependencies() {
    echo "Installing build dependencies..."
    sudo apt update
    sudo apt install -y \
        build-essential cmake git gfortran make pkg-config autoconf automake libtool asciidoc \
        qtbase5-dev qtmultimedia5-dev libqt5serialport5-dev libqt5websockets5-dev qttools5-dev qttools5-dev-tools \
        libfftw3-dev libboost-all-dev libreadline-dev libusb-1.0-0-dev libudev-dev libasound2-dev \
        ca-certificates curl wget
}

use_system_hamlib() {
    if [ "$USE_SYSTEM_HAMLIB" != "yes" ]; then
        return 1
    fi

    if ! command -v pkg-config >/dev/null 2>&1; then
        return 1
    fi

    if ! pkg-config --exists hamlib 2>/dev/null; then
        return 1
    fi

    HAMLIB_CMAKE_PREFIX="$(pkg-config --variable=prefix hamlib 2>/dev/null || true)"
    [ -n "$HAMLIB_CMAKE_PREFIX" ] || HAMLIB_CMAKE_PREFIX="/usr/local"
    HAMLIB_SOURCE="system"

    echo "Using system Hamlib $(pkg-config --modversion hamlib 2>/dev/null) from ${HAMLIB_CMAKE_PREFIX}"
    return 0
}

build_hamlib() {
    echo "Building Hamlib..."
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    rm -rf hamlib-src hamlib-build "$HAMLIB_PREFIX"

    git clone --depth 1 --branch "$HAMLIB_BRANCH" "$HAMLIB_REPO" hamlib-src
    cd hamlib-src
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
    rm -f wsjtx-*_improved_PLUS_*.tgz
    wget -O "$SOURCE_FILE" "$SOURCE_URL"
}

build_wsjtx() {
    echo "Building WSJT-X Improved..."
    cd "$BUILD_DIR"

    rm -rf wsjtx-src
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
    cmake --install . || true
}

copy_executables_from_dir() {
    local source_dir="$1"

    mkdir -p "$APP_BIN_DIR"

    find "$source_dir" -maxdepth 1 -type f -executable -print0 | while IFS= read -r -d '' file; do
        cp -f "$file" "$APP_BIN_DIR/$(basename "$file")"
        chmod +x "$APP_BIN_DIR/$(basename "$file")"
    done
}

package_built_app() {
    local installed_bin_dir="$APP_DIR/bin"
    local superbuild_bin_dir="$BUILD_DIR/wsjtx-src/build/wsjtx-prefix/src/wsjtx-build"
    local flat_bin_dir="$BUILD_DIR/wsjtx-src/build"
    local runtime_source_dir=""
    local source_icon=""

    rm -rf "$APP_DIR"
    mkdir -p "$APP_DIR" "$APP_BIN_DIR"

    if [ -x "$superbuild_bin_dir/wsjtx" ]; then
        runtime_source_dir="$superbuild_bin_dir"
        INSTALL_MODE="packaged-from-build"
    elif [ -x "$flat_bin_dir/wsjtx" ]; then
        runtime_source_dir="$flat_bin_dir"
        INSTALL_MODE="packaged-from-build"
    elif [ -x "$installed_bin_dir/wsjtx" ]; then
        runtime_source_dir="$installed_bin_dir"
        INSTALL_MODE="installed"
    else
        echo "Error: build finished but wsjtx binary was not found."
        exit 1
    fi

    copy_executables_from_dir "$runtime_source_dir"

    [ -x "$APP_BIN_DIR/wsjtx" ] || {
        echo "Error: packaged wsjtx binary was not found."
        exit 1
    }

    [ -x "$APP_BIN_DIR/jt9" ] || {
        echo "Error: packaged jt9 binary was not found."
        exit 1
    }

    TARGET_BIN="$APP_BIN_DIR/wsjtx"

    source_icon=$(find "$BUILD_DIR/wsjtx-src" -type f \( -name 'wsjtx*.png' -o -name 'wsjtx*.svg' -o -name 'wsjtx*.xpm' \) 2>/dev/null | head -n 1 || true)
    if [ -n "$source_icon" ]; then
        cp -f "$source_icon" "$ICON_FILE"
        ICON_PATH="$ICON_FILE"
    else
        ICON_PATH="applications-science"
    fi
}

make_launcher() {
    echo "Creating launcher..."
    mkdir -p "$HOME/.local/share/applications"
    mkdir -p "$HOME/Desktop"

    cat > "$WRAPPER_PATH" <<EOW
#!/bin/bash
export XDG_CONFIG_HOME="$CONFIG_DIR"
export XDG_DATA_HOME="$DATA_DIR"
mkdir -p "\$XDG_CONFIG_HOME" "\$XDG_DATA_HOME"
exec "$TARGET_BIN" "\$@"
EOW
    chmod +x "$WRAPPER_PATH"

    cat > "$LOCAL_DESKTOP_FILE" <<EOF2
[Desktop Entry]
Version=1.0
Name=WSJT-X Improved ${VERSION}
Comment=WSJT-X Improved ${VERSION}
Exec=${WRAPPER_PATH} %U
Icon=${ICON_PATH}
Terminal=false
Type=Application
Categories=AudioVideo;Audio;HamRadio;
StartupNotify=true
EOF2

    cp "$LOCAL_DESKTOP_FILE" "$DESKTOP_FILE"

    chmod +x "$LOCAL_DESKTOP_FILE"
    chmod +x "$DESKTOP_FILE"
    gio set "$DESKTOP_FILE" metadata::trusted true >/dev/null 2>&1 || true
    update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
}

cleanup_build_dir() {
    rm -rf "$BUILD_DIR"
}

echo "=== ${PROGRAM_NAME} Source Installer ==="

require_command sudo
require_command tar
require_command sed
require_command grep

detect_latest_release
switch_to_old_releases
install_dependencies
if ! use_system_hamlib; then
    build_hamlib
fi
download_source
build_wsjtx
package_built_app
make_launcher
cleanup_build_dir

echo "Done → run ${PROGRAM_NAME}-${VERSION}"
echo "Release detected: ${RELEASE_ID}"
echo "Hamlib source used: ${HAMLIB_SOURCE}"
echo "Install mode: ${INSTALL_MODE}"
