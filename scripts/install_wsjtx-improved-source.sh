#!/bin/bash
set -euo pipefail

# Author: Eric Rouse (VA3FYB)

# --- EDIT THESE if adapting for another program ---
PROGRAM_NAME="wsjtx-improved"
FILES_URL="https://sourceforge.net/projects/wsjt-x-improved/files/"
USE_SYSTEM_HAMLIB="yes"
HAMLIB_REPO="https://github.com/Hamlib/Hamlib.git"
HAMLIB_BRANCH="integration"
# --------------------------------------------------

# These are all computed at runtime — do not edit.
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

    # Pull the highest version folder name from the SourceForge file listing.
    latest_dir=$(printf '%s\n' "$page" | grep -oE 'WSJT-X_v[0-9]+(\.[0-9]+)+' | sort -Vu | tail -n 1)
    [ -n "$latest_dir" ] || {
        echo "Error: could not determine latest WSJT-X Improved version folder."
        exit 1
    }

    VERSION="${latest_dir#WSJT-X_v}"
    SOURCE_PAGE_URL="${FILES_URL}${latest_dir}/Source%20code/"
    source_page=$(wget -qO- "$SOURCE_PAGE_URL")

    # Find the standard Qt5 source tarball — exclude the AL (Amateur Linux),
    # widescreen, and qt6 variants which need different build handling.
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
    # Only applies to Ubuntu. If apt sources already point at old-releases,
    # or if this is not Ubuntu, nothing needs to change.
    if ! grep -q '^ID=ubuntu' /etc/os-release 2>/dev/null; then
        return 0
    fi

    if grep -q 'old-releases.ubuntu.com' /etc/apt/sources.list 2>/dev/null; then
        return 0
    fi

    # Ubuntu 22.10 is EOL. The default apt mirrors no longer carry its packages.
    # This rewrites sources.list to use the old-releases archive so apt update
    # and all dependency installs work correctly.
    echo "Switching apt sources to old-releases.ubuntu.com (required for EOL Ubuntu)..."
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
    # Try to use Hamlib that is already installed on the system before
    # building it from source — saves significant build time.
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
    echo "Building Hamlib from source (no system Hamlib found)..."
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

remove_previous_installs() {
    # Each install creates a versioned directory (e.g. wsjtx-improved-2.6.1).
    # When upgrading, we need to remove old versioned directories and their
    # desktop files so they don't pile up in ~/Applications and the app launcher.
    local old_dir old_basename

    while IFS= read -r old_dir; do
        [ -n "$old_dir" ] || continue
        old_basename="$(basename "$old_dir")"

        echo "Removing previous install: $old_dir"
        rm -rf "$old_dir"
        rm -f "$HOME/.local/share/applications/${old_basename}.desktop"
        rm -f "$HOME/Desktop/${old_basename}.desktop"
    done < <(find "$HOME/Applications" -maxdepth 1 -mindepth 1 -type d -name "${PROGRAM_NAME}-*" 2>/dev/null || true)

    update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
}

package_built_app() {
    local installed_bin_dir="$APP_DIR/bin"
    local superbuild_bin_dir="$BUILD_DIR/wsjtx-src/build/wsjtx-prefix/src/wsjtx-build"
    local flat_bin_dir="$BUILD_DIR/wsjtx-src/build"
    local runtime_source_dir=""
    local source_icon=""

    # Remove any previous versioned installs before creating the new one,
    # so old versions don't accumulate in ~/Applications and the app launcher.
    remove_previous_installs

    rm -rf "$APP_DIR"
    mkdir -p "$APP_DIR" "$APP_BIN_DIR"

    # cmake --install may place the binaries in different locations depending
    # on whether it used a superbuild or flat build. Check each in order.
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

    # The wrapper script sets isolated XDG config and data directories so
    # this install does not collide with any other WSJT-X installation.
    cat > "$WRAPPER_PATH" <<EOW
#!/bin/bash
export XDG_CONFIG_HOME="$CONFIG_DIR"
export XDG_DATA_HOME="$DATA_DIR"
mkdir -p "\$XDG_CONFIG_HOME" "\$XDG_DATA_HOME"
exec "$TARGET_BIN" "\$@"
EOW
    chmod +x "$WRAPPER_PATH"

    # Write the .desktop file. This is what makes the app appear in the
    # application launcher search and on the desktop.
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

    # Tell the desktop environment to re-scan for new/changed .desktop files
    # so the app shows up in the launcher search immediately.
    update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
}

cleanup_build_dir() {
    # Remove all source code and intermediate build files — they are no
    # longer needed once the program is installed.
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
