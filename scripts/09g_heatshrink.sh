#!/usr/bin/env bash
# Build heatshrink for iOS Simulator using a wrapper CMakeLists.
# heatshrink is a small compression library used by LibBGCode.
# The upstream Makefile is POSIX-only; we use a custom CMakeLists.
source "$(dirname "$0")/common.sh"
require_toolchain; require_sysroot

SENTINEL="$IOS_SYSROOT/lib/libheatshrink.a"
already_done "$SENTINEL" && exit 0

HEATSHRINK_SRC="$IOS_SOURCES/heatshrink"
WRAPPER_SRC="$IOS_SOURCES/heatshrink-ios-wrapper"
BUILD="$WRAPPER_SRC/build"

log_step "Building heatshrink for iOS Simulator"

# ── Clone heatshrink source ────────────────────────────────────────────────
if [ ! -d "$HEATSHRINK_SRC/.git" ]; then
    log_step "Cloning heatshrink"
    git clone --depth 1 https://github.com/atomicobject/heatshrink.git \
        "$HEATSHRINK_SRC"
fi

# ── Create wrapper directory with custom CMakeLists ────────────────────────
mkdir -p "$WRAPPER_SRC"

# Copy source files into wrapper (avoids path issues in iOS CMake)
for f in heatshrink_common.h heatshrink_config.h \
          heatshrink_decoder.c heatshrink_decoder.h \
          heatshrink_encoder.c heatshrink_encoder.h; do
    cp "$HEATSHRINK_SRC/$f" "$WRAPPER_SRC/$f"
done

cat > "$WRAPPER_SRC/CMakeLists.txt" << 'ENDCMAKE'
cmake_minimum_required(VERSION 3.14...4.3)
project(heatshrink LANGUAGES C VERSION 0.4.1)
set(CMAKE_C_STANDARD 99)

add_library(heatshrink STATIC
    heatshrink_decoder.c heatshrink_encoder.c)
target_include_directories(heatshrink PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:include/heatshrink>)
target_compile_definitions(heatshrink PUBLIC HEATSHRINK_DYNAMIC_ALLOC=0)

add_library(heatshrink_dynalloc STATIC
    heatshrink_decoder.c heatshrink_encoder.c)
target_include_directories(heatshrink_dynalloc PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:include/heatshrink>)
target_compile_definitions(heatshrink_dynalloc PUBLIC HEATSHRINK_DYNAMIC_ALLOC=1)

install(TARGETS heatshrink heatshrink_dynalloc ARCHIVE DESTINATION lib)
install(FILES heatshrink_common.h heatshrink_config.h
              heatshrink_encoder.h heatshrink_decoder.h
        DESTINATION include/heatshrink)
ENDCMAKE

# ── Build ─────────────────────────────────────────────────────────────────
cmake -S "$WRAPPER_SRC" -B "$BUILD" \
    "${CMAKE_COMMON[@]}" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5

cmake --build "$BUILD" -j"$NCPU"
cmake --install "$BUILD" --prefix "$IOS_SYSROOT"

# ── Write CMake package config so find_package(heatshrink) works ──────────
mkdir -p "$IOS_SYSROOT/lib/cmake/heatshrink"
cat > "$IOS_SYSROOT/lib/cmake/heatshrink/heatshrinkConfig.cmake" << 'ENDCONFIG'
if(NOT TARGET heatshrink::heatshrink)
  get_filename_component(_p "${CMAKE_CURRENT_LIST_DIR}/../../../" ABSOLUTE)
  add_library(heatshrink::heatshrink STATIC IMPORTED)
  set_target_properties(heatshrink::heatshrink PROPERTIES
    IMPORTED_LOCATION "${_p}/lib/libheatshrink.a"
    INTERFACE_INCLUDE_DIRECTORIES "${_p}/include"
    INTERFACE_COMPILE_DEFINITIONS "HEATSHRINK_DYNAMIC_ALLOC=0")
  add_library(heatshrink::heatshrink_dynalloc STATIC IMPORTED)
  set_target_properties(heatshrink::heatshrink_dynalloc PROPERTIES
    IMPORTED_LOCATION "${_p}/lib/libheatshrink_dynalloc.a"
    INTERFACE_INCLUDE_DIRECTORIES "${_p}/include"
    INTERFACE_COMPILE_DEFINITIONS "HEATSHRINK_DYNAMIC_ALLOC=1")
endif()
set(heatshrink_FOUND TRUE)
ENDCONFIG

log_ok "heatshrink installed"
log_ok "  libheatshrink.a         → $IOS_SYSROOT/lib/"
log_ok "  libheatshrink_dynalloc.a → $IOS_SYSROOT/lib/"
