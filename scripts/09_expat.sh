#!/usr/bin/env bash
# Build libexpat (XML parser used by libslic3r for config/3MF parsing)
source "$(dirname "$0")/common.sh"
require_toolchain; require_sysroot

SENTINEL="$IOS_SYSROOT/lib/libexpat.a"
already_done "$SENTINEL" && exit 0

log_step "Building libexpat"

SRC="$IOS_SOURCES/libexpat"
BUILD="$SRC/expat/build-ios-sim"

if [ ! -d "$SRC/.git" ]; then
    git clone --depth=1 --branch R_2_5_0 \
        https://github.com/libexpat/libexpat.git "$SRC" \
        || git clone --depth=1 https://github.com/libexpat/libexpat.git "$SRC"
fi

cmake -S "$SRC/expat" -B "$BUILD" \
    "${CMAKE_COMMON[@]}" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DEXPAT_BUILD_TESTS=OFF \
    -DEXPAT_BUILD_TOOLS=OFF \
    -DEXPAT_BUILD_EXAMPLES=OFF \
    -DEXPAT_SHARED_LIBS=OFF

cmake --build "$BUILD" -j"$NCPU" --target install

log_ok "libexpat installed → $IOS_SYSROOT/lib/libexpat.a"
