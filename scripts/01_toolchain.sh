#!/usr/bin/env bash
# Download the leetal/ios-cmake toolchain file
source "$(dirname "$0")/common.sh"

TOOLCHAIN_DIR="$HOME/ios-toolchain"
TOOLCHAIN_FILE="$TOOLCHAIN_DIR/ios.toolchain.cmake"
TOOLCHAIN_URL="https://raw.githubusercontent.com/leetal/ios-cmake/master/ios.toolchain.cmake"

log_step "Setting up iOS CMake toolchain"

if [ -f "$TOOLCHAIN_FILE" ]; then
    log_ok "Toolchain already present at $TOOLCHAIN_FILE"
    exit 0
fi

mkdir -p "$TOOLCHAIN_DIR"
curl -fL --progress-bar -o "$TOOLCHAIN_FILE" "$TOOLCHAIN_URL"
log_ok "Toolchain downloaded to $TOOLCHAIN_FILE"
