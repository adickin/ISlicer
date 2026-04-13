#!/usr/bin/env bash
# Build MPFR (Multiple Precision Floating-Point) for iOS Simulator.
# Depends on GMP (09b_gmp.sh must run first).
source "$(dirname "$0")/common.sh"
require_toolchain; require_sysroot

SENTINEL="$IOS_SYSROOT/lib/libmpfr.a"
already_done "$SENTINEL" && exit 0

if [ ! -f "$IOS_SYSROOT/lib/libgmp.a" ]; then
    log_error "GMP not found. Run 09b_gmp.sh first."
    exit 1
fi

MPFR_VER="4.2.2"
MPFR_SRC="$IOS_SOURCES/mpfr-$MPFR_VER"
MPFR_URL="https://www.mpfr.org/mpfr-current/mpfr-$MPFR_VER.tar.xz"

# Download & extract
if [ ! -d "$MPFR_SRC" ]; then
    log_step "Downloading MPFR $MPFR_VER"
    cd "$IOS_SOURCES"
    curl -L -o "mpfr-$MPFR_VER.tar.xz" "$MPFR_URL"
    tar xJf "mpfr-$MPFR_VER.tar.xz"
fi

SDK_PATH=$(xcrun --sdk "$IOS_SDK" --show-sdk-path)
IOS_CC=$(xcrun --sdk "$IOS_SDK" -f clang)
IOS_CXX=$(xcrun --sdk "$IOS_SDK" -f clang++)
TARGET_TRIPLE="$IOS_TARGET_TRIPLE"
CFLAGS="-arch arm64 -target $TARGET_TRIPLE -isysroot $SDK_PATH -O2"

log_step "Configuring MPFR $MPFR_VER for $PLATFORM"
BUILD_DIR="$IOS_SOURCES/mpfr-build-$BUILD_SUFFIX"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

"$MPFR_SRC/configure" \
    --host=aarch64-apple-darwin \
    --build="$(uname -m)-apple-darwin" \
    --prefix="$IOS_SYSROOT" \
    --enable-static \
    --disable-shared \
    --with-pic \
    --with-gmp="$IOS_SYSROOT" \
    CC="$IOS_CC" \
    CXX="$IOS_CXX" \
    CFLAGS="$CFLAGS" \
    CXXFLAGS="$CFLAGS" \
    CPP="$IOS_CC -E" \
    2>&1 | tee "$IOS_SOURCES/mpfr_configure.log"

log_step "Building MPFR"
make -j"$NCPU" 2>&1 | tee "$IOS_SOURCES/mpfr_build.log"

log_step "Installing MPFR"
make install 2>&1 | tee "$IOS_SOURCES/mpfr_install.log"

log_ok "MPFR installed → $IOS_SYSROOT/lib/libmpfr.a"
