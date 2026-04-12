#!/usr/bin/env bash
# Install CGAL 5.6.2 headers + cmake config for iOS.
# CGAL is header-only; GMP + MPFR provide exact arithmetic at link time.
#
# We download CGAL 5.6.2 directly from GitHub because:
# - Homebrew ships CGAL 6.x which has an incompatible API
#   (AABB_traits renamed, property_map() return type changed)
# - PrusaSlicer 2.7/2.8 targets CGAL 5.6.x
source "$(dirname "$0")/common.sh"
require_sysroot

SENTINEL="$IOS_SYSROOT/include/CGAL/version.h"
already_done "$SENTINEL" && exit 0

if [ ! -f "$IOS_SYSROOT/lib/libgmp.a" ]; then
    log_error "GMP not found. Run 09b_gmp.sh first."
    exit 1
fi
if [ ! -f "$IOS_SYSROOT/lib/libmpfr.a" ]; then
    log_error "MPFR not found. Run 09c_mpfr.sh first."
    exit 1
fi

CGAL_VER="5.6.2"
CGAL_SRC="$IOS_SOURCES/cgal-${CGAL_VER}-src"
CGAL_ZIP="$IOS_SOURCES/cgal-${CGAL_VER}.zip"

log_step "Downloading CGAL $CGAL_VER source"
if [ ! -d "$CGAL_SRC" ]; then
    if [ ! -f "$CGAL_ZIP" ]; then
        curl -L \
            "https://github.com/CGAL/cgal/releases/download/v${CGAL_VER}/CGAL-${CGAL_VER}.zip" \
            -o "$CGAL_ZIP"
    fi
    log_step "Extracting CGAL $CGAL_VER"
    cd "$IOS_SOURCES"
    unzip -q "$CGAL_ZIP"
    mv "CGAL-${CGAL_VER}" "$CGAL_SRC"
fi

log_step "Installing CGAL $CGAL_VER headers to sysroot"
mkdir -p "$IOS_SYSROOT/include"

# CGAL 5.6 stores headers in per-component include/CGAL/ dirs.
# Merge them all into a single $IOS_SYSROOT/include/CGAL/.
mkdir -p "$IOS_SYSROOT/include/CGAL"
find "$CGAL_SRC" -type d -name "CGAL" | while read -r srcdir; do
    # Skip build/binary dirs
    [[ "$srcdir" == *build* ]] && continue
    rsync -a "$srcdir/" "$IOS_SYSROOT/include/CGAL/" 2>/dev/null || \
        cp -Rn "$srcdir/." "$IOS_SYSROOT/include/CGAL/" 2>/dev/null || true
done

# Write a hand-crafted CMake package config so that find_package(CGAL) works
# and points at our sysroot GMP/MPFR instead of the host's.
mkdir -p "$IOS_SYSROOT/lib/cmake/CGAL"

cat > "$IOS_SYSROOT/lib/cmake/CGAL/CGALConfig.cmake" << 'ENDCMAKE'
# Minimal CGALConfig.cmake for iOS cross-compilation.
# CGAL 5.6.2 is header-only; GMP + MPFR are in the sysroot as static libs.

cmake_minimum_required(VERSION 3.10)

set(CGAL_FOUND TRUE)
set(CGAL_VERSION "5.6.2")
set(CGAL_VERSION_MAJOR 5)
set(CGAL_VERSION_MINOR 6)
set(CGAL_VERSION_PATCH 2)

# Locate this file's directory to derive the sysroot prefix
get_filename_component(_CGAL_CONFIG_DIR "${CMAKE_CURRENT_LIST_FILE}" PATH)
get_filename_component(_CGAL_PREFIX "${_CGAL_CONFIG_DIR}/../../.." ABSOLUTE)

if(NOT TARGET CGAL::CGAL)
    add_library(CGAL::CGAL INTERFACE IMPORTED)
    set_target_properties(CGAL::CGAL PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${_CGAL_PREFIX}/include"
        INTERFACE_LINK_LIBRARIES "${_CGAL_PREFIX}/lib/libmpfr.a;${_CGAL_PREFIX}/lib/libgmpxx.a;${_CGAL_PREFIX}/lib/libgmp.a"
        INTERFACE_COMPILE_DEFINITIONS "CGAL_USE_GMP;CGAL_USE_MPFR"
    )
endif()

# Some PrusaSlicer cmake code checks for these variables
set(CGAL_INCLUDE_DIRS "${_CGAL_PREFIX}/include")
set(CGAL_LIBRARIES "${_CGAL_PREFIX}/lib/libmpfr.a;${_CGAL_PREFIX}/lib/libgmpxx.a;${_CGAL_PREFIX}/lib/libgmp.a")
set(CGAL_LIBRARY_DIRS "${_CGAL_PREFIX}/lib")

# Provide the alias some code expects
if(NOT TARGET CGAL)
    add_library(CGAL ALIAS CGAL::CGAL)
endif()
ENDCMAKE

cat > "$IOS_SYSROOT/lib/cmake/CGAL/CGALConfigVersion.cmake" << 'ENDVER'
set(PACKAGE_VERSION "5.6.2")
if(PACKAGE_FIND_VERSION VERSION_LESS_EQUAL PACKAGE_VERSION)
    set(PACKAGE_VERSION_COMPATIBLE TRUE)
    if(PACKAGE_FIND_VERSION VERSION_EQUAL PACKAGE_VERSION)
        set(PACKAGE_VERSION_EXACT TRUE)
    endif()
else()
    set(PACKAGE_VERSION_COMPATIBLE FALSE)
endif()
ENDVER

log_ok "CGAL $CGAL_VER installed"
log_ok "  Headers → $IOS_SYSROOT/include/CGAL/"
log_ok "  Config  → $IOS_SYSROOT/lib/cmake/CGAL/"
