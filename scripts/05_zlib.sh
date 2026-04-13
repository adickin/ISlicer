#!/usr/bin/env bash
# Build zlib for iOS simulator
source "$(dirname "$0")/common.sh"
require_toolchain; require_sysroot

SENTINEL="$IOS_SYSROOT/lib/libz.a"
already_done "$SENTINEL" && exit 0

log_step "Building zlib"

SRC="$IOS_SOURCES/zlib"
BUILD="$SRC/build-$BUILD_SUFFIX"

if [ ! -d "$SRC/.git" ]; then
    git clone --depth=1 https://github.com/madler/zlib.git "$SRC"
fi

cmake -S "$SRC" -B "$BUILD" \
    "${CMAKE_COMMON[@]}"

# Build only the static library target — the example executables (zlib_example,
# minigzip) can't link on iOS and are not needed. Skipping "--target install"
# avoids the dependency on those targets.
cmake --build "$BUILD" -j"$NCPU" --target zlibstatic

# Manual install: copy headers + library into sysroot
mkdir -p "$IOS_SYSROOT/lib" "$IOS_SYSROOT/include"
cp "$BUILD/libz.a"          "$IOS_SYSROOT/lib/libz.a"
cp "$SRC/zlib.h"            "$IOS_SYSROOT/include/"
# zconf.h is generated into the build dir
cp "$BUILD/zconf.h"         "$IOS_SYSROOT/include/"

log_ok "zlib installed → $IOS_SYSROOT/lib/libz.a"
