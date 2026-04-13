#!/usr/bin/env bash
# Build boost::nowide from the already-downloaded Boost source tree.
# nowide uses only POSIX APIs so it builds cleanly on iOS.
# Must run AFTER 07_boost.sh (needs the Boost headers in sysroot).
source "$(dirname "$0")/common.sh"
require_toolchain; require_sysroot

SENTINEL="$IOS_SYSROOT/lib/libboost_nowide.a"
already_done "$SENTINEL" && exit 0

NOWIDE_SRC="$IOS_SOURCES/boost/libs/nowide"
BUILD="$NOWIDE_SRC/build-$BUILD_SUFFIX"

if [ ! -f "$NOWIDE_SRC/CMakeLists.txt" ]; then
    log_error "Boost nowide source not found at $NOWIDE_SRC"
    log_error "Run 07_boost.sh first to download Boost."
    exit 1
fi

log_step "Building boost::nowide from Boost source tree"

cmake -S "$NOWIDE_SRC" -B "$BUILD" \
    "${CMAKE_COMMON[@]}" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DBOOST_NOWIDE_INSTALL=ON \
    -DBOOST_NOWIDE_BUILD_TESTS=OFF \
    -DBOOST_NOWIDE_BUILD_CMAKE_TESTS=OFF \
    -DBUILD_TESTING=OFF \
    -DCMAKE_PREFIX_PATH="$IOS_SYSROOT" \
    -DBoost_USE_STATIC_LIBS=ON \
    -DBoost_USE_STATIC_RUNTIME=ON \
    -DBoost_INCLUDE_DIR="$IOS_SYSROOT/include"

# Build the library target only — the install target fails because the
# standalone nowide source tree has no include/ dir (headers are already
# in the sysroot from the main Boost b2 install).
cmake --build "$BUILD" -j"$NCPU" --target boost_nowide

# Manual install
LIB=$(find "$BUILD" -name 'libboost_nowide.a' | head -1)
if [ -z "$LIB" ]; then
    log_error "libboost_nowide.a not found in build dir after compilation"
    exit 1
fi
mkdir -p "$IOS_SYSROOT/lib"
cp "$LIB" "$IOS_SYSROOT/lib/libboost_nowide.a"
# Headers are already present from the main Boost install; nothing to copy.

log_ok "boost::nowide installed → $IOS_SYSROOT/lib/libboost_nowide.a"
