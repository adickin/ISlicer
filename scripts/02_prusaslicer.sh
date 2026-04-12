#!/usr/bin/env bash
# Clone PrusaSlicer and initialise submodules
source "$(dirname "$0")/common.sh"

log_step "Cloning PrusaSlicer"

if [ -d "$PRUSA_SRC/.git" ]; then
    log_ok "PrusaSlicer already cloned at $PRUSA_SRC"
    # Ensure submodules are initialised even if we skipped
    cd "$PRUSA_SRC"
    git submodule update --init --recursive --depth=1
    exit 0
fi

mkdir -p "$IOS_SOURCES"
git clone --depth=1 https://github.com/prusa3d/PrusaSlicer.git "$PRUSA_SRC"
cd "$PRUSA_SRC"
git submodule update --init --recursive --depth=1

log_ok "PrusaSlicer cloned to $PRUSA_SRC"
log_ok "Source target: $PRUSA_SRC/src/libslic3r"
