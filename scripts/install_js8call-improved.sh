#!/bin/bash
set -euo pipefail

# Author: Eric Rouse (VA3FYB)

# --- EDIT THESE if adapting for another program ---
PROGRAM_NAME="js8call-improved"
APP_SLUG="${PROGRAM_NAME}"
DISPLAY_NAME="JS8Call Improved"
SOURCE_TAG="latest"
SOURCE_REPO="https://github.com/JS8Call-improved/JS8Call-improved"
LATEST_RELEASE_API="https://api.github.com/repos/JS8Call-improved/JS8Call-improved/releases/latest"
USE_SYSTEM_QT="yes"
BUILD_PRIVATE_QT_IF_NEEDED="yes"
QT_SOURCE_VERSION="auto"
QT_RELEASES_URL="https://download.qt.io/archive/qt"
QT_REQUIRED_COMPONENTS="Core Widgets Network Multimedia SerialPort"
USE_SYSTEM_HAMLIB="yes"
HAMLIB_REPO="https://github.com/Hamlib/Hamlib.git"
HAMLIB_BRANCH=""
USE_SYSTEM_BOOST="yes"
BUILD_PRIVATE_BOOST_IF_NEEDED="yes"
BOOST_SOURCE_VERSION="auto"
BOOST_RELEASES_URL="https://archives.boost.io/release"
APP_DIR="$HOME/Applications/${APP_SLUG}"
BUILD_DIR="$HOME/Downloads/${APP_SLUG}_build"
WRAPPER_PATH="$APP_DIR/run-${APP_SLUG}.sh"
LOCAL_DESKTOP_FILE="$HOME/.local/share/applications/${APP_SLUG}.desktop"
CONFIG_DIR="$HOME/.config/${APP_SLUG}"
DATA_DIR="$HOME/.local/share/${APP_SLUG}"
QT_APP_PREFIX="$APP_DIR/Qt"
# --------------------------------------------------

VERSION=""
RELEASE_ID=""
SOURCE_FILE=""
SOURCE_URL=""
SOURCE_DIR=""
QT_MIN_VERSION="6.5"
QT_PREFIX="$BUILD_DIR/qt-prefix"
QT_CMAKE_PREFIX=""
QT_RUNTIME_SOURCE_DIR=""
QT_SOURCE="built"
HAMLIB_PREFIX="$BUILD_DIR/hamlib-prefix"
HAMLIB_CMAKE_PREFIX="$HAMLIB_PREFIX"
HAMLIB_SOURCE="built"
BOOST_MIN_VERSION="1.77"
BOOST_PREFIX="$BUILD_DIR/boost-prefix"
BOOST_CMAKE_PREFIX="$BOOST_PREFIX"
BOOST_INCLUDE_DIR=""
BOOST_SOURCE="built"
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

show_build_notice() {
    cat <<EOF
ATTENTION: This installer may need to build Qt from source.
This can take several hours. Prepare to wait.
If a compatible cached Qt build is already present, it will be reused.
Continuing in 30 seconds. Press Ctrl+C to cancel.
EOF
    sleep 30
}

version_ge() {
    [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n 1)" = "$2" ]
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
        build-essential cmake ninja-build git make pkg-config perl python3 wget ca-certificates tar xz-utils \
        autoconf automake libtool texinfo \
        libhamlib-dev libfftw3-dev libboost-all-dev libusb-1.0-0-dev libudev-dev \
        libssl-dev libfontconfig1-dev libfreetype-dev libharfbuzz-dev libjpeg-dev libpng-dev \
        zlib1g-dev libbrotli-dev libdbus-1-dev libglib2.0-dev libatspi2.0-dev \
        libgl-dev libegl-dev libgbm-dev libopengl-dev libdrm-dev libinput-dev libvulkan-dev \
        libxkbcommon-dev libxkbcommon-x11-dev libxcb1-dev libx11-dev libx11-xcb-dev \
        libxcb-util-dev libxcb-image0-dev libxcb-keysyms1-dev libxcb-render-util0-dev \
        libxcb-icccm4-dev libxcb-cursor-dev libxcb-xinerama0-dev libxcb-xfixes0-dev \
        libxcb-shape0-dev libxcb-randr0-dev libxcb-sync-dev libxrender-dev libxi-dev \
        libxrandr-dev libxext-dev libxfixes-dev libxshmfence-dev \
        libpulse-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
        libavcodec-dev libavformat-dev libavutil-dev libswresample-dev libswscale-dev \
        libwayland-dev wayland-protocols

    sudo apt install -y libasound2-dev || sudo apt install -y libasound2t64

    if [ "$USE_SYSTEM_QT" = "yes" ]; then
        echo "Installing distro Qt6 development packages, if available..."
        sudo apt install -y qt6-base-dev qt6-multimedia-dev qt6-serialport-dev || \
            echo "Warning: distro Qt6 development packages could not be installed. A private Qt build will be used if enabled." >&2
    fi
}

cleanup() {
    rm -rf "$BUILD_DIR"
}

detect_latest_release_tag() {
    local page="" tag=""

    page="$(wget -qO- "$LATEST_RELEASE_API")"
    tag="$(printf '%s\n' "$page" \
        | grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"v[0-9]+(\.[0-9]+)*"' \
        | head -n 1 \
        | sed -E 's/.*"([^"]+)".*/\1/' || true)"

    [ -n "$tag" ] || die "could not detect latest JS8Call Improved release tag"
    printf '%s\n' "$tag"
}

detect_source_release() {
    echo "Detecting JS8Call Improved source release..."

    if [ "$SOURCE_TAG" = "latest" ]; then
        SOURCE_TAG="$(detect_latest_release_tag)"
    fi

    VERSION="${SOURCE_TAG#v}"
    RELEASE_ID="$VERSION"
    SOURCE_FILE="JS8Call-improved-${SOURCE_TAG}.tar.gz"
    SOURCE_URL="${SOURCE_REPO}/archive/refs/tags/${SOURCE_TAG}.tar.gz"

    echo "Release selected: ${SOURCE_TAG}"
}

download_source() {
    echo "Downloading JS8Call Improved source..."
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    wget -O "$SOURCE_FILE" "$SOURCE_URL"
}

extract_source() {
    echo "Extracting source..."
    local qt_components=""

    cd "$BUILD_DIR"
    rm -rf js8call-src
    mkdir -p js8call-src
    tar -xzf "$SOURCE_FILE" -C js8call-src --strip-components=1
    SOURCE_DIR="$BUILD_DIR/js8call-src"
    [ -f "$SOURCE_DIR/CMakeLists.txt" ] || die "source extraction did not create a CMake project"

    QT_MIN_VERSION="$(sed -nE 's/.*find_package\(Qt6[[:space:]]+([0-9]+(\.[0-9]+)?).*/\1/p' "$SOURCE_DIR/CMakeLists.txt" | head -n 1 || true)"
    [ -n "$QT_MIN_VERSION" ] || QT_MIN_VERSION="6.5"
    if grep -RqsE 'setTimeZone[[:space:]]*\([[:space:]]*QTimeZone' "$SOURCE_DIR" && ! version_ge "$QT_MIN_VERSION" "6.7"; then
        echo "Source uses Qt timezone editing APIs that require Qt 6.7+."
        QT_MIN_VERSION="6.7"
    fi
    echo "Qt requirement detected: ${QT_MIN_VERSION}+"

    qt_components="$(sed -nE 's/.*find_package\(Qt6[^)]*COMPONENTS[[:space:]]+([^)]*)\).*/\1/p' "$SOURCE_DIR/CMakeLists.txt" | head -n 1 | tr -s '[:space:]' ' ' | sed -E 's/^ //; s/ $//' || true)"
    if [ -n "$qt_components" ]; then
        QT_REQUIRED_COMPONENTS="Core ${qt_components}"
    fi
    echo "Qt modules required: ${QT_REQUIRED_COMPONENTS}"

    BOOST_MIN_VERSION="$(sed -nE 's/.*find_package[[:space:]]*\([[:space:]]*Boost[[:space:]]+([0-9]+(\.[0-9]+)+).*/\1/p' "$SOURCE_DIR/CMakeLists.txt" | head -n 1 || true)"
    [ -n "$BOOST_MIN_VERSION" ] || BOOST_MIN_VERSION="1.77"
    echo "Boost requirement detected: ${BOOST_MIN_VERSION}+"
}

use_system_hamlib() {
    [ "$USE_SYSTEM_HAMLIB" = "yes" ] || return 1
    command -v pkg-config >/dev/null 2>&1 || return 1
    pkg-config --exists hamlib 2>/dev/null || return 1

    HAMLIB_CMAKE_PREFIX="$(pkg-config --variable=prefix hamlib 2>/dev/null || true)"
    [ -n "$HAMLIB_CMAKE_PREFIX" ] || HAMLIB_CMAKE_PREFIX="/usr"
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

use_system_boost() {
    local include_dir="" version=""

    [ "$USE_SYSTEM_BOOST" = "yes" ] || return 1

    for include_dir in /usr/local/include /usr/include; do
        [ -f "$include_dir/boost/version.hpp" ] || continue
        version="$(sed -nE 's/^#define BOOST_LIB_VERSION "([0-9_]+)".*/\1/p' "$include_dir/boost/version.hpp" | head -n 1 | tr '_' '.')"
        [ -n "$version" ] || continue

        if version_ge "$version" "$BOOST_MIN_VERSION"; then
            BOOST_INCLUDE_DIR="$include_dir"
            case "$include_dir" in
                /usr/include) BOOST_CMAKE_PREFIX="/usr" ;;
                */include) BOOST_CMAKE_PREFIX="${include_dir%/include}" ;;
                *) BOOST_CMAKE_PREFIX="/usr" ;;
            esac
            BOOST_SOURCE="system"
            echo "Using system Boost ${version} from ${BOOST_INCLUDE_DIR}"
            return 0
        fi

        echo "System Boost ${version} from ${include_dir} is older than required ${BOOST_MIN_VERSION}."
    done

    return 1
}

detect_latest_boost_source_version() {
    local minimum_version="$1"
    local page="" candidate="" selected="" source_url=""

    echo "Detecting latest Boost source release..." >&2
    page="$(wget -qO- "${BOOST_RELEASES_URL}/")"

    while IFS= read -r candidate; do
        if version_ge "$candidate" "$minimum_version"; then
            source_url="${BOOST_RELEASES_URL}/${candidate}/source-nodocs/boost_${candidate//./_}.tar.gz"
            if wget -q --spider "$source_url"; then
                selected="$candidate"
            fi
        fi
    done <<EOF
$(printf '%s\n' "$page" \
    | grep -oE 'href="[0-9]+\.[0-9]+\.[0-9]+/' \
    | sed -E 's|href="([^/]+)/|\1|' \
    | sort -Vu)
EOF

    [ -n "$selected" ] || die "could not detect a Boost source release at least ${minimum_version}"
    printf '%s\n' "$selected"
}

resolve_boost_source_version() {
    if [ "$BOOST_SOURCE_VERSION" = "auto" ]; then
        BOOST_SOURCE_VERSION="$(detect_latest_boost_source_version "$BOOST_MIN_VERSION")"
    fi

    version_ge "$BOOST_SOURCE_VERSION" "$BOOST_MIN_VERSION" || die "Boost source ${BOOST_SOURCE_VERSION} is older than required Boost ${BOOST_MIN_VERSION}"
    echo "Boost source selected: ${BOOST_SOURCE_VERSION}"
}

build_private_boost() {
    local boost_archive_version="" boost_source_file="" boost_source_url="" boost_source_dir=""

    [ "$BUILD_PRIVATE_BOOST_IF_NEEDED" = "yes" ] || die "Boost ${BOOST_MIN_VERSION}+ was not found and private Boost builds are disabled"

    resolve_boost_source_version

    boost_archive_version="${BOOST_SOURCE_VERSION//./_}"
    boost_source_file="boost_${boost_archive_version}.tar.gz"
    boost_source_url="${BOOST_RELEASES_URL}/${BOOST_SOURCE_VERSION}/source-nodocs/${boost_source_file}"
    boost_source_dir="$BUILD_DIR/boost_${boost_archive_version}"

    echo "Installing private Boost ${BOOST_SOURCE_VERSION} headers..."
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    if [ ! -f "$boost_source_file" ]; then
        wget -O "$boost_source_file" "$boost_source_url"
    fi

    rm -rf "$boost_source_dir" "$BOOST_PREFIX"
    tar -xzf "$boost_source_file"
    [ -d "$boost_source_dir/boost" ] || die "Boost source extraction did not create expected headers"

    mkdir -p "$BOOST_PREFIX/include"
    cp -a "$boost_source_dir/boost" "$BOOST_PREFIX/include/"

    BOOST_INCLUDE_DIR="$BOOST_PREFIX/include"
    BOOST_CMAKE_PREFIX="$BOOST_PREFIX"
    BOOST_SOURCE="built"
}

select_boost() {
    if ! use_system_boost; then
        build_private_boost
    fi
}

detect_system_qt_version() {
    local version=""

    if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists Qt6Core 2>/dev/null; then
        version="$(pkg-config --modversion Qt6Core 2>/dev/null || true)"
    fi

    if [ -z "$version" ] && command -v qmake6 >/dev/null 2>&1; then
        version="$(qmake6 -query QT_VERSION 2>/dev/null || true)"
    fi

    if [ -z "$version" ] && command -v qtpaths6 >/dev/null 2>&1; then
        version="$(qtpaths6 --qt-version 2>/dev/null || true)"
    fi

    [ -n "$version" ] || return 1
    printf '%s\n' "$version"
}

detect_system_qt_prefix() {
    local prefix=""

    if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists Qt6Core 2>/dev/null; then
        prefix="$(pkg-config --variable=prefix Qt6Core 2>/dev/null || true)"
    fi

    if [ -z "$prefix" ] && command -v qmake6 >/dev/null 2>&1; then
        prefix="$(qmake6 -query QT_INSTALL_PREFIX 2>/dev/null || true)"
    fi

    [ -n "$prefix" ] || prefix="/usr"
    printf '%s\n' "$prefix"
}

detect_qt_prefix_version() {
    local prefix="$1"
    local version=""

    if [ -x "$prefix/bin/qtpaths6" ]; then
        version="$("$prefix/bin/qtpaths6" --qt-version 2>/dev/null || true)"
    fi

    if [ -z "$version" ] && [ -x "$prefix/bin/qmake6" ]; then
        version="$("$prefix/bin/qmake6" -query QT_VERSION 2>/dev/null || true)"
    fi

    if [ -z "$version" ] && [ -f "$prefix/lib/cmake/Qt6Core/Qt6CoreConfigVersion.cmake" ]; then
        version="$(sed -nE 's/^[[:space:]]*set\(PACKAGE_VERSION[[:space:]]+"([^"]+)".*/\1/p' "$prefix/lib/cmake/Qt6Core/Qt6CoreConfigVersion.cmake" | head -n 1 || true)"
    fi

    [ -n "$version" ] || return 1
    printf '%s\n' "$version"
}

missing_qt_components() {
    local prefix="$1"
    local component="" missing=""

    for component in $QT_REQUIRED_COMPONENTS; do
        if [ ! -f "$prefix/lib/cmake/Qt6${component}/Qt6${component}Config.cmake" ]; then
            missing="${missing}${missing:+ }${component}"
        fi
    done

    printf '%s\n' "$missing"
}

detect_latest_qt_source_version() {
    local minimum_version="$1"
    local minimum_major="" page="" branch="" branch_page="" candidate="" selected="" source_url=""

    minimum_major="$(printf '%s\n' "$minimum_version" | sed -E 's/^([0-9]+).*/\1/')"
    [ -n "$minimum_major" ] || die "could not determine Qt major version from ${minimum_version}"

    echo "Detecting latest Qt ${minimum_major}.x source release at least ${minimum_version}..." >&2
    page="$(wget -qO- "${QT_RELEASES_URL}/")"

    while IFS= read -r branch; do
        branch_page="$(wget -qO- "${QT_RELEASES_URL}/${branch}/" || true)"
        [ -n "$branch_page" ] || continue

        while IFS= read -r candidate; do
            if version_ge "$candidate" "$minimum_version"; then
                source_url="${QT_RELEASES_URL}/${candidate%.*}/${candidate}/single/qt-everywhere-src-${candidate}.tar.xz"
                if wget -q --spider "$source_url"; then
                    selected="$candidate"
                fi
            fi
        done <<EOF
$(printf '%s\n' "$branch_page" \
    | grep -oE "href=\"${branch//./\\.}\.[0-9]+/" \
    | sed -E 's|href="([^/]+)/|\1|' \
    | sort -Vu)
EOF
    done <<EOF
$(printf '%s\n' "$page" \
    | grep -oE "href=\"${minimum_major}\.[0-9]+/" \
    | sed -E 's|href="([^/]+)/|\1|' \
    | sort -Vu)
EOF

    [ -n "$selected" ] || die "could not detect a Qt ${minimum_major}.x source release at least ${minimum_version}"
    printf '%s\n' "$selected"
}

resolve_qt_source_version() {
    if [ "$QT_SOURCE_VERSION" = "auto" ]; then
        QT_SOURCE_VERSION="$(detect_latest_qt_source_version "$QT_MIN_VERSION")"
    fi

    version_ge "$QT_SOURCE_VERSION" "$QT_MIN_VERSION" || die "Qt source ${QT_SOURCE_VERSION} is older than required Qt ${QT_MIN_VERSION}"
    echo "Qt source selected: ${QT_SOURCE_VERSION}"
}

use_system_qt() {
    local qt_version=""

    [ "$USE_SYSTEM_QT" = "yes" ] || return 1
    qt_version="$(detect_system_qt_version || true)"
    [ -n "$qt_version" ] || return 1

    if version_ge "$qt_version" "$QT_MIN_VERSION"; then
        QT_CMAKE_PREFIX="$(detect_system_qt_prefix)"
        QT_SOURCE="system"
        echo "Using system Qt ${qt_version} from ${QT_CMAKE_PREFIX}"
        return 0
    fi

    echo "System Qt ${qt_version} is older than required Qt ${QT_MIN_VERSION}."
    return 1
}

use_cached_private_qt() {
    local qt_version="" missing=""

    [ -d "$QT_APP_PREFIX" ] || return 1

    qt_version="$(detect_qt_prefix_version "$QT_APP_PREFIX" || true)"
    if [ -z "$qt_version" ]; then
        echo "Existing private Qt was found, but its version could not be detected."
        return 1
    fi

    if ! version_ge "$qt_version" "$QT_MIN_VERSION"; then
        echo "Existing private Qt ${qt_version} is older than required Qt ${QT_MIN_VERSION}."
        return 1
    fi

    missing="$(missing_qt_components "$QT_APP_PREFIX")"
    if [ -n "$missing" ]; then
        echo "Existing private Qt ${qt_version} is missing required modules: ${missing}"
        return 1
    fi

    QT_CMAKE_PREFIX="$QT_APP_PREFIX"
    QT_RUNTIME_SOURCE_DIR="$QT_APP_PREFIX"
    QT_SOURCE="cached"
    echo "Using cached private Qt ${qt_version} from ${QT_APP_PREFIX}"
    return 0
}

build_private_qt() {
    resolve_qt_source_version

    local qt_source_file="qt-everywhere-src-${QT_SOURCE_VERSION}.tar.xz"
    local qt_source_url="${QT_RELEASES_URL}/${QT_SOURCE_VERSION%.*}/${QT_SOURCE_VERSION}/single/${qt_source_file}"
    local qt_source_dir="$BUILD_DIR/qt-everywhere-src-${QT_SOURCE_VERSION}"
    local qt_build_dir="$BUILD_DIR/qt-build"

    [ "$BUILD_PRIVATE_QT_IF_NEEDED" = "yes" ] || die "Qt ${QT_MIN_VERSION}+ was not found and private Qt builds are disabled"

    echo "Building private Qt ${QT_SOURCE_VERSION}. This can take a long time."
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    if [ ! -f "$qt_source_file" ]; then
        wget -O "$qt_source_file" "$qt_source_url"
    fi

    rm -rf "$qt_source_dir" "$qt_build_dir" "$QT_PREFIX"
    tar -xJf "$qt_source_file"
    mkdir -p "$qt_build_dir"
    cd "$qt_build_dir"

    "$qt_source_dir/configure" \
        -prefix "$QT_PREFIX" \
        -release \
        -opensource \
        -confirm-license \
        -nomake examples \
        -nomake tests \
        -no-feature-spatialaudio \
        -skip qtquick3d \
        -skip qtquick3dphysics \
        -submodules qtbase,qtshadertools,qtmultimedia,qtserialport

    cmake --build . --parallel "$(nproc)"
    cmake --install .

    mkdir -p "$QT_PREFIX/bin"
    cat > "$QT_PREFIX/bin/qt.conf" <<EOF
[Paths]
Prefix = ..
Plugins = ../plugins
Libraries = ../lib
EOF

    QT_CMAKE_PREFIX="$QT_PREFIX"
    QT_RUNTIME_SOURCE_DIR="$QT_PREFIX"
    QT_SOURCE="built"
}

select_qt() {
    if use_system_qt; then
        return 0
    fi

    if use_cached_private_qt; then
        return 0
    fi

    build_private_qt
}

build_and_stage_js8call() {
    local build_dir="$BUILD_DIR/js8call-build"
    local staging_root="$BUILD_DIR/stage"
    local staged_app_dir="${staging_root}${APP_DIR}"
    local cmake_prefix_path="${QT_CMAKE_PREFIX};${HAMLIB_CMAKE_PREFIX};${BOOST_CMAKE_PREFIX}"
    local boost_no_system_paths="OFF"

    [ "$BOOST_SOURCE" = "built" ] && boost_no_system_paths="ON"

    echo "Building JS8Call Improved..."
    rm -rf "$build_dir" "$staging_root"
    mkdir -p "$build_dir"
    cd "$build_dir"

    cmake \
        -D CMAKE_BUILD_TYPE=Release \
        -D CMAKE_PREFIX_PATH="$cmake_prefix_path" \
        -D HAMLIB_ROOT="$HAMLIB_CMAKE_PREFIX" \
        -D BOOST_ROOT="$BOOST_CMAKE_PREFIX" \
        -D Boost_INCLUDE_DIR="$BOOST_INCLUDE_DIR" \
        -D Boost_NO_SYSTEM_PATHS="$boost_no_system_paths" \
        -D CMAKE_INSTALL_PREFIX="$APP_DIR" \
        "$SOURCE_DIR"

    cmake --build . -j"$(nproc)"

    [ -x "$build_dir/JS8Call" ] || die "built JS8Call binary was not found"

    mkdir -p "$staged_app_dir/bin"
    cp "$build_dir/JS8Call" "$staged_app_dir/bin/JS8Call"
    chmod +x "$staged_app_dir/bin/JS8Call"

    if [ "$QT_SOURCE" != "system" ]; then
        [ -n "$QT_RUNTIME_SOURCE_DIR" ] || die "private Qt source directory was not set"
        echo "Staging private Qt runtime..."
        mkdir -p "$staged_app_dir/Qt"
        cp -a "$QT_RUNTIME_SOURCE_DIR"/. "$staged_app_dir/Qt"/
        cat > "$staged_app_dir/Qt/bin/qt.conf" <<EOF
[Paths]
Prefix = ..
Plugins = ../plugins
Libraries = ../lib
EOF
    fi

    if [ -f "$SOURCE_DIR/artwork/icon_128.svg" ]; then
        cp "$SOURCE_DIR/artwork/icon_128.svg" "$staged_app_dir/${PROGRAM_NAME}.svg"
    elif [ -f "$SOURCE_DIR/artwork/js8call_icon.png" ]; then
        cp "$SOURCE_DIR/artwork/js8call_icon.png" "$staged_app_dir/${PROGRAM_NAME}.png"
    fi

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
if [ -d "$APP_DIR/Qt/lib" ]; then
    export LD_LIBRARY_PATH="$APP_DIR/Qt/lib:$APP_DIR/lib:\${LD_LIBRARY_PATH:-}"
    export QT_PLUGIN_PATH="$APP_DIR/Qt/plugins"
    export QML2_IMPORT_PATH="$APP_DIR/Qt/qml"
else
    export LD_LIBRARY_PATH="$APP_DIR/lib:\${LD_LIBRARY_PATH:-}"
fi
mkdir -p "\$XDG_CONFIG_HOME" "\$XDG_DATA_HOME"
exec "$APP_DIR/bin/JS8Call" "\$@"
EOF
    chmod +x "$WRAPPER_PATH"
}

create_launcher() {
    local desktop_dir="$1"
    local desktop_file="$desktop_dir/${APP_SLUG}.desktop"

    ICON_PATH="$(find "$APP_DIR" -maxdepth 2 -type f \( -iname '*js8call*.png' -o -iname '*js8call*.svg' -o -iname '*js8*.png' -o -iname '*js8*.svg' \) | head -n 1 || true)"
    [ -n "$ICON_PATH" ] || ICON_PATH="applications-science"

    mkdir -p "$HOME/.local/share/applications" "$desktop_dir"

    cat > "$LOCAL_DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=${DISPLAY_NAME}
Comment=JS8 weak-signal messaging
Exec="$WRAPPER_PATH" %U
Icon=${ICON_PATH}
Terminal=false
Type=Application
Categories=AudioVideo;Audio;HamRadio;Network;
StartupNotify=true
EOF

    cp "$LOCAL_DESKTOP_FILE" "$desktop_file"
    chmod +x "$LOCAL_DESKTOP_FILE" "$desktop_file"
    gio set "$desktop_file" metadata::trusted true >/dev/null 2>&1 || true
    update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
}

show_build_notice
echo "=== ${DISPLAY_NAME} Source Installer ==="

require_command wget
require_command grep
require_command sort
require_command tar
require_command sed
ensure_safe_app_dir
trap cleanup EXIT

detect_source_release
install_dependencies
if ! use_system_hamlib; then
    build_hamlib
fi
download_source
extract_source
select_boost
select_qt
build_and_stage_js8call
replace_app_dir "$STAGED_APP_DIR"
create_wrapper
create_launcher "$(get_desktop_dir)"

echo "Done -> run ${DISPLAY_NAME}"
echo "Release built: ${RELEASE_ID}"
echo "Qt source used: ${QT_SOURCE}"
echo "Hamlib source used: ${HAMLIB_SOURCE}"
echo "Boost source used: ${BOOST_SOURCE}"
echo "Installed to: $APP_DIR"
echo "Config not touched except this app's own config: $CONFIG_DIR"
