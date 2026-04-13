#!/usr/bin/env bash
# Build Boost for iOS simulator (arm64).
# This is the hardest step — budget 20-40 min on first run.
# Uses Boost's b2 build system with a hand-written user-config.jam.
source "$(dirname "$0")/common.sh"
require_sysroot

SENTINEL="$IOS_SYSROOT/lib/libboost_system.a"
already_done "$SENTINEL" && exit 0

log_step "Building Boost for iOS simulator"

BOOST_VERSION="1.84.0"
BOOST_TARBALL_NAME="boost_${BOOST_VERSION//./_}"
SRC="$IOS_SOURCES/boost"
BUILD_DIR="$SRC/build-$BUILD_SUFFIX"

# Download if not present
if [ ! -d "$SRC" ]; then
    mkdir -p "$IOS_SOURCES"
    URL="https://archives.boost.io/release/${BOOST_VERSION}/source/${BOOST_TARBALL_NAME}.tar.gz"
    TARBALL="/tmp/${BOOST_TARBALL_NAME}.tar.gz"
    log_step "Downloading Boost ${BOOST_VERSION}..."
    curl -fL --progress-bar -o "$TARBALL" "$URL"
    tar -xzf "$TARBALL" -C "$IOS_SOURCES"
    mv "$IOS_SOURCES/${BOOST_TARBALL_NAME}" "$SRC"
    rm -f "$TARBALL"
fi

cd "$SRC"

# Build the b2 tool for the HOST (not cross-compiled)
if [ ! -f "./b2" ]; then
    log_step "Bootstrapping Boost b2 build tool"
    ./bootstrap.sh --with-toolset=clang
fi

# Determine SDK path and toolchain at runtime
SDK_PATH=$(xcrun --sdk "$IOS_SDK" --show-sdk-path)
CLANGPP=$(xcrun --find clang++)
CLANG=$(xcrun --find clang)

# Write user-config.jam for cross-compilation
# Toolset name must be a valid Boost identifier — use BUILD_SUFFIX with hyphens replaced
BOOST_TOOLSET="clang_${BUILD_SUFFIX//-/_}"
cat > user-config.jam << EOF
using clang : ${BUILD_SUFFIX//-/_}
    : "${CLANGPP}"
    : <cflags>"-arch arm64 -target ${IOS_TARGET_TRIPLE} -isysroot ${SDK_PATH} -fembed-bitcode-marker"
      <cxxflags>"-arch arm64 -target ${IOS_TARGET_TRIPLE} -isysroot ${SDK_PATH} -fembed-bitcode-marker -std=c++17"
      <linkflags>"-arch arm64 -target ${IOS_TARGET_TRIPLE} -isysroot ${SDK_PATH}"
      <compileflags>"-DBOOST_AC_USE_PTHREADS -DBOOST_SP_USE_PTHREADS"
    ;
EOF

log_step "Building Boost libraries (this takes a while)..."
./b2 \
    --user-config=user-config.jam \
    --build-dir="$BUILD_DIR" \
    toolset="clang-${BUILD_SUFFIX//-/_}" \
    target-os=iphone \
    architecture=arm \
    address-model=64 \
    link=static \
    threading=multi \
    runtime-link=static \
    variant=release \
    --with-atomic \
    --with-chrono \
    --with-date_time \
    --with-filesystem \
    --with-iostreams \
    --with-log \
    --with-program_options \
    --with-regex \
    --with-system \
    --with-thread \
    -sNO_BZIP2=1 \
    -sNO_ZSTD=1 \
    -sZLIB_INCLUDE="$IOS_SYSROOT/include" \
    -sZLIB_LIBPATH="$IOS_SYSROOT/lib" \
    -j"$NCPU" \
    --prefix="$IOS_SYSROOT" \
    install \
    2>&1 | tee "$IOS_SOURCES/boost_build.log" | grep -E '(error:|warning:|Building|Install|FAILED)' || true

# Check result
if [ -f "$IOS_SYSROOT/lib/libboost_system.a" ]; then
    log_ok "Boost installed → $IOS_SYSROOT/lib/libboost_system.a"
else
    log_error "Boost build failed. Check $IOS_SOURCES/boost_build.log"
    log_warn "Tip: If Boost.Log fails, try removing --with-log and rebuild libslic3r without log support"
    exit 1
fi
