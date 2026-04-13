#!/usr/bin/env bash
# Build libpng for iOS simulator (depends on zlib)
source "$(dirname "$0")/common.sh"
require_toolchain; require_sysroot

SENTINEL="$IOS_SYSROOT/lib/libpng.a"
already_done "$SENTINEL" && exit 0

log_step "Building libpng"

SRC="$IOS_SOURCES/libpng"
BUILD="$SRC/build-$BUILD_SUFFIX"

if [ ! -d "$SRC/.git" ]; then
    git clone --depth=1 --branch v1.6.43 https://github.com/pnggroup/libpng.git "$SRC" \
        || git clone --depth=1 https://github.com/pnggroup/libpng.git "$SRC"
fi

cmake -S "$SRC" -B "$BUILD" \
    "${CMAKE_COMMON[@]}" \
    -DCMAKE_PREFIX_PATH="$IOS_SYSROOT" \
    -DPNG_TESTS=OFF \
    -DPNG_SHARED=OFF \
    -DPNG_STATIC=ON \
    -DPNG_FRAMEWORK=OFF \
    -DZLIB_ROOT="$IOS_SYSROOT"

cmake --build "$BUILD" -j"$NCPU" --target install

log_ok "libpng installed → $IOS_SYSROOT/lib/libpng.a"
