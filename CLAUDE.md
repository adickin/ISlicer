# CLAUDE.md — IosSlicer

Guidelines and context for AI-assisted development on this project.

## Project Summary

iOS on-device 3D printing slicer. Embeds libslic3r (PrusaSlicer's C++ core) as a static library, wrapped by a thin C bridge, consumed by a SwiftUI app. No cloud, no network, all slicing runs on-device.

This project is entirely AI-written. See README.md for architecture and PROGRESS.md for feature status.

## Key Paths

| Path | Purpose |
|------|---------|
| `~/ios-sysroot-sim/` | All cross-compiled deps (static `.a` + headers) |
| `~/ios-sources/` | All cloned source repos |
| `~/ios-sources/PrusaSlicer/` | Full PrusaSlicer tree — libslic3r lives at `src/libslic3r/` |
| `~/ios-toolchain/ios.toolchain.cmake` | leetal/ios-cmake toolchain |
| `scripts/common.sh` | Shared env vars — read this before touching any build script |
| `app/project.yml` | xcodegen spec — source of truth for Xcode build settings |

## Build System

- Steps are numbered scripts in `scripts/`. Each is idempotent via a sentinel file (typically a `.a` in `~/ios-sysroot-sim/lib/`).
- To force a rebuild of a step, delete its sentinel and re-run. E.g.: `rm ~/ios-sysroot-sim/lib/libslic3r.a && bash scripts/10_libslic3r.sh`
- After any change to `app/project.yml` run `xcodegen` from the `app/` directory before building in Xcode.
- After any change to libslic3r or its deps, re-run `scripts/11_xcframework.sh` to update the XCFramework headers.
- Current target: **SIMULATORARM64** (iPhone Simulator on Apple Silicon). Device build (`PLATFORM=OS64`) is not yet done.

## PrusaSlicer Modifications

We patch the PrusaSlicer source tree directly. All changes are gated on the `SLIC3R_IOS` cmake option so the upstream desktop build is unaffected.

**Files modified:**
- `~/ios-sources/PrusaSlicer/CMakeLists.txt` — added `SLIC3R_IOS` option; gated CURL, OpenGL/GLEW, NLopt, OpenVDB
- `~/ios-sources/PrusaSlicer/src/CMakeLists.txt` — gated `libseqarrange` add_subdirectory and PrusaSlicer install block
- `~/ios-sources/PrusaSlicer/src/libslic3r/CMakeLists.txt` — excluded JPEG; swapped stub source files; gated libseqarrange link

**Stub files added to PrusaSlicer source:**
- `src/libslic3r/ArrangeHelper_ios_stub.cpp` — replaces ArrangeHelper.cpp; `check_seq_conflict` returns nullopt
- `src/libslic3r/GCode/Thumbnails_ios_stub.cpp` — replaces Thumbnails.cpp; compress_thumbnail returns empty buffer

**Stub headers in sysroot** (`~/ios-sysroot-sim/include/`):
- `libseqarrange/seq_interface.hpp` — Sequential types as forward-declared pointers, no Z3
- `nlopt.h` — from NLopt 2.5.0 source (header only; SLA code compiles but is never called in FDM path)
- `nanosvg/nanosvg.h` — from fltk/nanosvg fork

## C Bridge (`app/IosSlicer/slicer_bridge.h/.cpp`)

The only interface between Swift and C++. Swift cannot call C++ directly.

Key API:
```c
SlicerHandle slicer_create();
void         slicer_destroy(SlicerHandle);
int          slicer_load_stl(SlicerHandle, const char* path);
int          slicer_slice(SlicerHandle, float layer_height, int infill_percent);
int          slicer_export_gcode(SlicerHandle, const char* output_path);
const char*  slicer_last_error(SlicerHandle);
```

When adding new slicing features (supports, brim, printer profiles, etc.), add parameters or new functions here first — don't reach into libslic3r types from Swift.

## Adding a New Dependency

1. Write a numbered script in `scripts/` following the existing pattern (source `common.sh`, check sentinel, build, install to `$IOS_SYSROOT`).
2. Add it to `build.sh` in the correct order.
3. If it needs a cmake package config, either install it from the build or hand-write a minimal `*Config.cmake` in `$IOS_SYSROOT/lib/cmake/<name>/`.
4. Add any headers that libslic3r or the bridge includes to `$IOS_SYSROOT/include/`.
5. Add the `.a` to `OTHER_LDFLAGS` in `app/project.yml`.
6. Run `xcodegen` and verify the app still links.

## Common Failure Modes

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `cmake_minimum_required < 3.5` error | CMake 4.x broke older projects | Add `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` to the cmake invocation |
| `file not found` for a bundled dep header | XCFramework headers dir doesn't include bundled_deps | Add the missing header to `$IOS_SYSROOT/include/` and regenerate the XCFramework |
| `MACOSX_BUNDLE` error on an executable target | iOS toolchain treats all executables as app bundles | Write a custom CMakeLists that omits the executable, or gate it with `SLIC3R_IOS` |
| Boost static runtime mismatch | Boost built with `runtime-link=static` but cmake finder not told | Ensure `Boost_USE_STATIC_RUNTIME=ON` is passed |
| CGAL version mismatch | PrusaSlicer uses CGAL 5.6.2 API; CGAL 6.x changed `property_map()` | Use the CGAL 5.6.2 headers from `~/ios-sources/cgal-5.6.2-src/`, not homebrew |
| Undefined symbol at link | A new dep was added to libslic3r but not to `OTHER_LDFLAGS` | Add the `.a` path to `app/project.yml` and run `xcodegen` |
| `export()` call fails at cmake configure | Upstream uses `export()` which requires shared lib targets iOS doesn't have | Write a custom minimal CMakeLists (see Qhull and heatshrink scripts for examples) |

## Coding Conventions

- **C bridge functions** return `int` (0 = success, negative = error) and store the error string in the context via `slicer_last_error()`. Don't throw across the C boundary.
- **Swift side** always checks the return value and shows an alert on failure — don't silently swallow errors.
- **No shared libraries** anywhere in the dep chain. iOS prohibits loading dynamic libraries at runtime (outside of system frameworks).
- **No bitcode** (`ENABLE_BITCODE: NO`) — deprecated in Xcode 14 and incompatible with our cross-compiled static libs.
- C++ standard is **C++17** throughout. Match this in any new files.

## libslic3r API Notes (PrusaSlicer version in use)

Check the actual commit: `cd ~/ios-sources/PrusaSlicer && git log --oneline -1`

Key call sites in `slicer_bridge.cpp` to watch when updating PrusaSlicer:
- `Slic3r::load_stl(path, &model, nullptr)` — returns bool
- `print.apply(model, std::move(config))` — takes model + moved config
- `print.process()` — blocks; no progress callback in current bridge
- `print.export_gcode(path, nullptr, nullptr)` — third arg is thumbnail callback
