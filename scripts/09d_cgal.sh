#!/usr/bin/env bash
# Install CGAL headers + cmake config for iOS.
# CGAL 5.x+ is header-only; GMP + MPFR provide exact arithmetic at link time.
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

CGAL_BREW="/opt/homebrew/Cellar/cgal/6.1.1"
if [ ! -d "$CGAL_BREW" ]; then
    log_error "CGAL not found via homebrew. Run: brew install cgal"
    exit 1
fi

log_step "Installing CGAL headers to sysroot"
mkdir -p "$IOS_SYSROOT/include"
# CGAL is header-only – just copy the include dir
cp -R "$CGAL_BREW/include/CGAL" "$IOS_SYSROOT/include/"

# Write a hand-crafted CMake package config so that find_package(CGAL) works
# and points at our sysroot GMP/MPFR instead of the host's.
mkdir -p "$IOS_SYSROOT/lib/cmake/CGAL"

cat > "$IOS_SYSROOT/lib/cmake/CGAL/CGALConfig.cmake" << 'ENDCMAKE'
# Minimal CGALConfig.cmake for iOS cross-compilation.
# CGAL is header-only; GMP + MPFR are in the sysroot as static libs.

cmake_minimum_required(VERSION 3.10)

set(CGAL_FOUND TRUE)
set(CGAL_VERSION "6.1.1")
set(CGAL_VERSION_MAJOR 6)
set(CGAL_VERSION_MINOR 1)
set(CGAL_VERSION_PATCH 1)

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
set(PACKAGE_VERSION "6.1.1")
if("${PACKAGE_FIND_VERSION_MAJOR}" STREQUAL "" OR
   "${PACKAGE_FIND_VERSION_MAJOR}.${PACKAGE_FIND_VERSION_MINOR}" VERSION_LESS_EQUAL "6.1")
    set(PACKAGE_VERSION_COMPATIBLE TRUE)
    if(PACKAGE_FIND_VERSION VERSION_EQUAL PACKAGE_VERSION)
        set(PACKAGE_VERSION_EXACT TRUE)
    endif()
else()
    set(PACKAGE_VERSION_COMPATIBLE FALSE)
endif()
ENDVER

log_ok "CGAL installed"
log_ok "  Headers → $IOS_SYSROOT/include/CGAL/"
log_ok "  Config  → $IOS_SYSROOT/lib/cmake/CGAL/"
