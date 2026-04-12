#!/usr/bin/env bash
# Package libslic3r.a (simulator slice) as a single-platform XCFramework.
# Run 10_libslic3r.sh before this.
#
# For a dual sim+device XCFramework, build again with PLATFORM=OS64 into
# IOS_SYSROOT_DEV and add a second -library / -headers pair below.
source "$(dirname "$0")/common.sh"

APP_DIR="$PROJECT_ROOT/app"
XCFW="$APP_DIR/libslic3r.xcframework"
LIB="$IOS_SYSROOT/lib/libslic3r.a"
HEADERS="$IOS_SYSROOT/include"

if [ ! -f "$LIB" ]; then
    log_error "libslic3r.a not found at $LIB — run 10_libslic3r.sh first."
    exit 1
fi

log_step "Packaging XCFramework"

rm -rf "$XCFW"
xcodebuild -create-xcframework \
    -library "$LIB" \
    -headers "$HEADERS" \
    -output "$XCFW"

log_ok "XCFramework → $XCFW"
log_warn "This is a SIMULATOR-only XCFramework (SIMULATORARM64)."
log_warn "For device builds, rebuild deps+libslic3r with PLATFORM=OS64"
log_warn "then add the device slice to the xcodebuild -create-xcframework call."
