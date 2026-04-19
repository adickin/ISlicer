# CLAUDE.md — IosSlicer

Guidelines and context for AI-assisted development on this project.

## Project Summary

iOS on-device 3D printing slicer. Embeds libslic3r (PrusaSlicer's C++ core) as a static library, wrapped by a thin C bridge, consumed by a SwiftUI app. No cloud, no network, all slicing runs on-device.

This project is entirely AI-written. See README.md for architecture and PROGRESS.md for feature status.

## Key Paths

| Path | Purpose |
|------|---------|
| `~/ios-sysroot-sim/` | All cross-compiled deps (static `.a` + headers) |
| `~/ios-sources/PrusaSlicer/` | Full PrusaSlicer tree — libslic3r lives at `src/libslic3r/` |
| `scripts/common.sh` | Shared env vars — read this before touching any build script |
| `app/project.yml` | xcodegen spec — source of truth for Xcode build settings |

## Build System

- Steps are numbered scripts in `scripts/`. Each is idempotent via a sentinel file (typically a `.a` in `~/ios-sysroot-sim/lib/`).
- To force a rebuild of a step, delete its sentinel and re-run. E.g.: `rm ~/ios-sysroot-sim/lib/libslic3r.a && bash scripts/10_libslic3r.sh`
- After any change to `app/project.yml` run `xcodegen` from the `app/` directory before building in Xcode.
- After any change to libslic3r or its deps, re-run `scripts/11_xcframework.sh` to update the XCFramework headers.
- Current target: **SIMULATORARM64** (iPhone Simulator on Apple Silicon). Device build (`PLATFORM=OS64`) is not yet done.

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

## Common Failure Modes

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `cmake_minimum_required < 3.5` error | CMake 4.x broke older projects | Add `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` to the cmake invocation |
| CGAL version mismatch | PrusaSlicer uses CGAL 5.6.2 API; CGAL 6.x changed `property_map()` | Use the CGAL 5.6.2 headers from `~/ios-sources/cgal-5.6.2-src/`, not homebrew |
| Undefined symbol at link | A new dep was added to libslic3r but not to `OTHER_LDFLAGS` | Add the `.a` path to `app/project.yml` and run `xcodegen` |

## Coding Conventions

- **C bridge functions** return `int` (0 = success, negative = error) and store the error string in the context via `slicer_last_error()`. Don't throw across the C boundary.
- **Swift side** always checks the return value and shows an alert on failure — don't silently swallow errors.
- **No shared libraries** anywhere in the dep chain. iOS prohibits loading dynamic libraries at runtime (outside of system frameworks).
- **No bitcode** (`ENABLE_BITCODE: NO`) — deprecated in Xcode 14 and incompatible with our cross-compiled static libs.
- C++ standard is **C++17** throughout. Match this in any new files.
