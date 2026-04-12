#!/usr/bin/env bash
# Build Qhull for iOS Simulator using a custom wrapper CMakeLists.
# The upstream Qhull CMakeLists fails on iOS because its export() call
# requires shared library support, which iOS prohibits.
source "$(dirname "$0")/common.sh"
require_toolchain; require_sysroot

SENTINEL="$IOS_SYSROOT/lib/libqhullstatic_r.a"
already_done "$SENTINEL" && exit 0

QHULL_SRC="$IOS_SOURCES/qhull"
QHULL_VER="2020.2"  # tag 8.0.2
WRAPPER_SRC="$IOS_SOURCES/qhull-ios-wrapper"
BUILD="$WRAPPER_SRC/build"

log_step "Building Qhull $QHULL_VER for iOS Simulator"

# ── Clone Qhull source ────────────────────────────────────────────────────
if [ ! -d "$QHULL_SRC/.git" ]; then
    log_step "Cloning Qhull"
    git clone --depth 1 --branch "v$QHULL_VER" \
        https://github.com/qhull/qhull.git "$QHULL_SRC"
fi

# ── Create wrapper directory with custom CMakeLists ───────────────────────
mkdir -p "$WRAPPER_SRC"

cat > "$WRAPPER_SRC/CMakeLists.txt" << 'ENDCMAKE'
# Minimal Qhull build for iOS — bypasses the upstream CMakeLists which
# fails on iOS because its export() call requires shared library targets
# that iOS doesn't support.
cmake_minimum_required(VERSION 3.14...4.3)
project(qhull_ios CXX C)

# Allow the actual qhull source to be passed in; fall back to this file's dir
if(NOT DEFINED QHULL_SRC)
  set(QHULL_SRC "${CMAKE_CURRENT_SOURCE_DIR}")
endif()

# ── libqhull_r (C, reentrant) ─────────────────────────────────────────────
file(GLOB QHULL_R_SRCS "${QHULL_SRC}/src/libqhull_r/*.c")
add_library(qhullstatic_r STATIC ${QHULL_R_SRCS})
target_include_directories(qhullstatic_r PUBLIC "${QHULL_SRC}/src")

# ── libqhullcpp (C++) ─────────────────────────────────────────────────────
file(GLOB QHULL_CPP_SRCS "${QHULL_SRC}/src/libqhullcpp/*.cpp")
list(REMOVE_ITEM QHULL_CPP_SRCS
    "${QHULL_SRC}/src/libqhullcpp/qt-qhull.cpp"
    "${QHULL_SRC}/src/libqhullcpp/usermem_r-cpp.cpp"
)
add_library(qhullcpp STATIC ${QHULL_CPP_SRCS})
target_include_directories(qhullcpp PUBLIC "${QHULL_SRC}/src")
target_link_libraries(qhullcpp PRIVATE qhullstatic_r)

# ── Install ───────────────────────────────────────────────────────────────
install(TARGETS qhullstatic_r qhullcpp
        ARCHIVE DESTINATION lib)
install(DIRECTORY "${QHULL_SRC}/src/libqhull_r"
        DESTINATION include
        FILES_MATCHING PATTERN "*.h")
install(DIRECTORY "${QHULL_SRC}/src/libqhullcpp"
        DESTINATION include
        FILES_MATCHING PATTERN "*.h")

# ── CMake package config ──────────────────────────────────────────────────
include(CMakePackageConfigHelpers)

configure_package_config_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/QhullConfig-ios.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/QhullConfig.cmake"
    INSTALL_DESTINATION "lib/cmake/Qhull"
)
write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/QhullConfigVersion.cmake"
    VERSION 8.0.2
    COMPATIBILITY AnyNewerVersion
)
install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/QhullConfig.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/QhullConfigVersion.cmake"
    DESTINATION "lib/cmake/Qhull"
)
ENDCMAKE

cat > "$WRAPPER_SRC/QhullConfig-ios.cmake.in" << 'ENDTEMPLATE'
@PACKAGE_INIT@

if(NOT TARGET Qhull::qhullstatic_r)
  add_library(Qhull::qhullstatic_r STATIC IMPORTED)
  set_target_properties(Qhull::qhullstatic_r PROPERTIES
    IMPORTED_LOCATION "${PACKAGE_PREFIX_DIR}/lib/libqhullstatic_r.a"
    INTERFACE_INCLUDE_DIRECTORIES "${PACKAGE_PREFIX_DIR}/include"
  )
endif()

if(NOT TARGET Qhull::qhullcpp)
  add_library(Qhull::qhullcpp STATIC IMPORTED)
  set_target_properties(Qhull::qhullcpp PROPERTIES
    IMPORTED_LOCATION "${PACKAGE_PREFIX_DIR}/lib/libqhullcpp.a"
    INTERFACE_INCLUDE_DIRECTORIES "${PACKAGE_PREFIX_DIR}/include"
    INTERFACE_LINK_LIBRARIES "Qhull::qhullstatic_r"
  )
endif()
ENDTEMPLATE

# ── Build ─────────────────────────────────────────────────────────────────
cmake -S "$WRAPPER_SRC" -B "$BUILD" \
    "${CMAKE_COMMON[@]}" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DQHULL_SRC="$QHULL_SRC"

cmake --build "$BUILD" -j"$NCPU"
cmake --install "$BUILD" --prefix "$IOS_SYSROOT"

log_ok "Qhull installed"
log_ok "  libqhullstatic_r.a → $IOS_SYSROOT/lib/"
log_ok "  libqhullcpp.a      → $IOS_SYSROOT/lib/"
