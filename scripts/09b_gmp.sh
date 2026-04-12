#!/usr/bin/env bash
# Build GMP (GNU Multiple Precision) for iOS Simulator.
# Uses --disable-assembly for pure-C portable build.
source "$(dirname "$0")/common.sh"
require_toolchain; require_sysroot

SENTINEL="$IOS_SYSROOT/lib/libgmp.a"
already_done "$SENTINEL" && exit 0

GMP_VER="6.3.0"
GMP_SRC="$IOS_SOURCES/gmp-$GMP_VER"
GMP_URL="https://gmplib.org/download/gmp/gmp-$GMP_VER.tar.xz"

# Download & extract
if [ ! -d "$GMP_SRC" ]; then
    log_step "Downloading GMP $GMP_VER"
    cd "$IOS_SOURCES"
    curl -L -o "gmp-$GMP_VER.tar.xz" "$GMP_URL"
    tar xJf "gmp-$GMP_VER.tar.xz"
fi

SDK_PATH=$(xcrun --sdk iphonesimulator --show-sdk-path)
IOS_CC=$(xcrun --sdk iphonesimulator -f clang)
IOS_CXX=$(xcrun --sdk iphonesimulator -f clang++)
TARGET_TRIPLE="arm64-apple-ios${DEPLOYMENT_TARGET}-simulator"
CFLAGS="-arch arm64 -target $TARGET_TRIPLE -isysroot $SDK_PATH -O2"

log_step "Configuring GMP $GMP_VER for iOS Simulator"
BUILD_DIR="$IOS_SOURCES/gmp-build-ios-sim"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

"$GMP_SRC/configure" \
    --host=aarch64-apple-darwin \
    --build="$(uname -m)-apple-darwin" \
    --prefix="$IOS_SYSROOT" \
    --enable-static \
    --disable-shared \
    --disable-assembly \
    --enable-cxx \
    --with-pic \
    CC="$IOS_CC" \
    CXX="$IOS_CXX" \
    CFLAGS="$CFLAGS" \
    CXXFLAGS="$CFLAGS" \
    CPP="$IOS_CC -E" \
    2>&1 | tee "$IOS_SOURCES/gmp_configure.log"

log_step "Building GMP"
make -j"$NCPU" 2>&1 | tee "$IOS_SOURCES/gmp_build.log"

log_step "Installing GMP"
make install 2>&1 | tee "$IOS_SOURCES/gmp_install.log"

log_ok "GMP installed → $IOS_SYSROOT/lib/libgmp.a"
