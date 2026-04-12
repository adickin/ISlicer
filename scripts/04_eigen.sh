#!/usr/bin/env bash
# Install Eigen3 headers — header-only, no compilation needed.
source "$(dirname "$0")/common.sh"
require_sysroot

SENTINEL="$IOS_SYSROOT/include/eigen3/Eigen/Core"
already_done "$SENTINEL" && exit 0

log_step "Installing Eigen3 headers"

SRC="$IOS_SOURCES/eigen"
if [ ! -d "$SRC/.git" ]; then
    # Use the version bundled with PrusaSlicer if already cloned
    BUNDLED="$PRUSA_SRC/deps/deps.cmake"
    if [ -f "$BUNDLED" ]; then
        # Try to get the Eigen version from PrusaSlicer's deps
        EIGEN_VER=$(grep -i 'eigen' "$PRUSA_SRC/deps/deps.cmake" 2>/dev/null | grep -oP '3\.\d+\.\d+' | head -1 || echo "3.4.0")
        log_warn "Detected Eigen version from deps: $EIGEN_VER"
    fi
    git clone --depth=1 --branch 3.4.0 https://gitlab.com/libeigen/eigen.git "$SRC" \
        || git clone --depth=1 https://gitlab.com/libeigen/eigen.git "$SRC"
fi

# Eigen is header-only — just copy the headers
cmake -S "$SRC" -B "$SRC/build-ios" \
    -DCMAKE_INSTALL_PREFIX="$IOS_SYSROOT" \
    -DBUILD_TESTING=OFF \
    -DEIGEN_BUILD_PKGCONFIG=OFF
cmake --build "$SRC/build-ios" --target install

log_ok "Eigen3 headers → $IOS_SYSROOT/include/eigen3"
