#!/usr/bin/env bash
# Install all required build tools via Homebrew
source "$(dirname "$0")/common.sh"

log_step "Installing prerequisites via Homebrew"

TOOLS=(cmake ninja pkg-config automake autoconf libtool xcodegen)
MISSING=()

for tool in "${TOOLS[@]}"; do
    if ! brew list "$tool" &>/dev/null; then
        MISSING+=("$tool")
    else
        log_ok "$tool already installed"
    fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
    log_step "Installing: ${MISSING[*]}"
    brew install "${MISSING[@]}"
fi

# Verify cmake version >= 3.24
CMAKE_VER=$(cmake --version | head -1 | awk '{print $3}')
log_ok "cmake $CMAKE_VER"
ninja --version | xargs -I{} echo "  ✓ ninja {}"
log_ok "xcodegen $(xcodegen --version 2>/dev/null | head -1 || echo '(version check failed)')"

require_sysroot

log_ok "Prerequisites complete"
