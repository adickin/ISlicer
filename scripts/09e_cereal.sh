#!/usr/bin/env bash
# Install cereal (header-only serialization library) + CMake config.
# PrusaSlicer bundles cereal in deps/; we download directly from GitHub.
source "$(dirname "$0")/common.sh"
require_sysroot

SENTINEL="$IOS_SYSROOT/include/cereal/cereal.hpp"
already_done "$SENTINEL" && exit 0

CEREAL_SRC="$IOS_SOURCES/cereal"
CEREAL_VER="1.3.2"

log_step "Installing cereal $CEREAL_VER (header-only)"

if [ ! -d "$CEREAL_SRC/include/cereal" ]; then
    log_step "Downloading cereal $CEREAL_VER"
    mkdir -p "$IOS_SOURCES"
    cd "$IOS_SOURCES"
    if [ ! -d "$CEREAL_SRC" ]; then
        git clone --depth 1 --branch "v$CEREAL_VER" \
            https://github.com/USCiLab/cereal.git cereal
    fi
fi

# Copy headers into sysroot
mkdir -p "$IOS_SYSROOT/include"
cp -R "$CEREAL_SRC/include/cereal" "$IOS_SYSROOT/include/"

# Write CMake package config so find_package(cereal) works
mkdir -p "$IOS_SYSROOT/lib/cmake/cereal"
cat > "$IOS_SYSROOT/lib/cmake/cereal/cerealConfig.cmake" << 'ENDCMAKE'
# Minimal cerealConfig.cmake for iOS sysroot.
cmake_minimum_required(VERSION 3.10)

get_filename_component(_cereal_PREFIX "${CMAKE_CURRENT_LIST_DIR}/../../../" ABSOLUTE)

if(NOT TARGET cereal::cereal)
    add_library(cereal::cereal INTERFACE IMPORTED)
    set_target_properties(cereal::cereal PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${_cereal_PREFIX}/include"
    )
endif()

set(CEREAL_FOUND TRUE)
set(CEREAL_INCLUDE_DIR "${_cereal_PREFIX}/include")
ENDCMAKE

cat > "$IOS_SYSROOT/lib/cmake/cereal/cerealConfigVersion.cmake" << 'ENDVER'
set(PACKAGE_VERSION "1.3.2")
if(PACKAGE_FIND_VERSION VERSION_LESS_EQUAL PACKAGE_VERSION)
    set(PACKAGE_VERSION_COMPATIBLE TRUE)
    if(PACKAGE_FIND_VERSION VERSION_EQUAL PACKAGE_VERSION)
        set(PACKAGE_VERSION_EXACT TRUE)
    endif()
else()
    set(PACKAGE_VERSION_COMPATIBLE FALSE)
endif()
ENDVER

log_ok "cereal installed → $IOS_SYSROOT/include/cereal/"
