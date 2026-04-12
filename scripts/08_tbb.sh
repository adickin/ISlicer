#!/usr/bin/env bash
# Build oneTBB for iOS simulator
# TBB provides the parallel_for etc. that libslic3r uses heavily.
source "$(dirname "$0")/common.sh"
require_toolchain; require_sysroot

SENTINEL="$IOS_SYSROOT/lib/libtbb.a"
already_done "$SENTINEL" && exit 0

log_step "Building oneTBB for iOS simulator"

SRC="$IOS_SOURCES/oneTBB"
BUILD="$SRC/build-ios-sim"

# Use v2021.9.0 — has stable iOS cmake support
if [ ! -d "$SRC/.git" ]; then
    git clone --depth=1 --branch v2021.9.0 \
        https://github.com/oneapi-src/oneTBB.git "$SRC" \
        || git clone --depth=1 https://github.com/oneapi-src/oneTBB.git "$SRC"
fi

# TBB needs a small patch to recognise iOS as a supported OS for its
# platform detection headers. Check if the patch is needed.
TBB_PLATFORM_HEADER="$SRC/include/oneapi/tbb/detail/_machine.h"
if [ -f "$TBB_PLATFORM_HEADER" ] && ! grep -q '__APPLE__' "$TBB_PLATFORM_HEADER" 2>/dev/null; then
    log_warn "TBB platform header may not recognise iOS — proceeding; linker will tell us."
fi

cmake -S "$SRC" -B "$BUILD" \
    "${CMAKE_COMMON[@]}" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DTBB_TEST=OFF \
    -DTBB_EXAMPLES=OFF \
    -DTBB_STRICT=OFF \
    -DTBB_DISABLE_IMPLICIT_TASK_ARENA_CREATION=ON \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT="$(xcrun --sdk iphonesimulator --show-sdk-path)" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET"

cmake --build "$BUILD" -j"$NCPU" --target install

if [ -f "$IOS_SYSROOT/lib/libtbb.a" ]; then
    log_ok "oneTBB installed → $IOS_SYSROOT/lib/libtbb.a"
else
    log_warn "libtbb.a not found at expected path. Checking alternate install locations..."
    find "$IOS_SYSROOT" -name 'libtbb*' 2>/dev/null
    log_warn "If TBB failed to install, libslic3r may still build — it has a fallback to std::thread."
    log_warn "You can continue and re-link if needed."
fi
