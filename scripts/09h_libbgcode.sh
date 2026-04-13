#!/usr/bin/env bash
# Build LibBGCode (Prusa binary G-code format library) for iOS Simulator.
# LibBGCode_BUILD_CMD_TOOL=OFF because the iOS toolchain wraps executables
# as MACOSX_BUNDLE and the bgcode CLI won't build.
source "$(dirname "$0")/common.sh"
require_toolchain; require_sysroot

SENTINEL="$IOS_SYSROOT/lib/libbgcode_core.a"
already_done "$SENTINEL" && exit 0

# Verify deps
for dep in libheatshrink.a libz.a; do
    if [ ! -f "$IOS_SYSROOT/lib/$dep" ]; then
        log_error "$dep not found in sysroot. Run prerequisite scripts first."
        exit 1
    fi
done

LIBBGCODE_SRC="$IOS_SOURCES/libbgcode"
BUILD="$LIBBGCODE_SRC/build-$BUILD_SUFFIX"

log_step "Cloning LibBGCode (Prusa binary gcode format)"
if [ ! -d "$LIBBGCODE_SRC/.git" ]; then
    git clone --depth 1 --branch main \
        https://github.com/prusa3d/libbgcode.git "$LIBBGCODE_SRC"
fi

log_step "Building LibBGCode for iOS Simulator"
cmake -S "$LIBBGCODE_SRC" -B "$BUILD" \
    "${CMAKE_COMMON[@]}" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    \
    -DLibBGCode_BUILD_CMD_TOOL=OFF \
    -DLibBGCode_BUILD_TESTS=OFF \
    -DLibBGCode_BUILD_DEPS=OFF \
    \
    -DZLIB_ROOT="$IOS_SYSROOT" \
    -DZLIB_LIBRARY="$IOS_SYSROOT/lib/libz.a" \
    -DZLIB_INCLUDE_DIR="$IOS_SYSROOT/include" \
    -Dheatshrink_DIR="$IOS_SYSROOT/lib/cmake/heatshrink" \
    -DCMAKE_PREFIX_PATH="$IOS_SYSROOT"

cmake --build "$BUILD" -j"$NCPU"
cmake --install "$BUILD" --prefix "$IOS_SYSROOT"

log_ok "LibBGCode installed"
log_ok "  libbgcode_core.a     → $IOS_SYSROOT/lib/"
log_ok "  libbgcode_binarize.a → $IOS_SYSROOT/lib/"
log_ok "  libbgcode_convert.a  → $IOS_SYSROOT/lib/"
log_ok "  Headers              → $IOS_SYSROOT/include/LibBGCode/"
