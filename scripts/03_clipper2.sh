#!/usr/bin/env bash
# Build Clipper2 — first real dep, also a toolchain smoke test.
# Success indicator: $IOS_SYSROOT/lib/libClipper2.a
source "$(dirname "$0")/common.sh"
require_toolchain; require_sysroot

SENTINEL="$IOS_SYSROOT/lib/libClipper2.a"
already_done "$SENTINEL" && exit 0

log_step "Building Clipper2"

SRC="$IOS_SOURCES/Clipper2"
BUILD="$SRC/build-$BUILD_SUFFIX"

if [ ! -d "$SRC/.git" ]; then
    git clone --depth=1 https://github.com/AngusJohnson/Clipper2.git "$SRC"
fi

cmake -S "$SRC/CPP" -B "$BUILD" \
    "${CMAKE_COMMON[@]}" \
    -DCLIPPER2_UTILS=OFF \
    -DCLIPPER2_EXAMPLES=OFF \
    -DCLIPPER2_TESTS=OFF

cmake --build "$BUILD" -j"$NCPU" --target install

log_ok "Clipper2 installed → $IOS_SYSROOT/lib/libClipper2.a"
