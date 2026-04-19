# SlicePal

An iOS on-device 3D printing slicer. Loads an STL, slices it using libslic3r (PrusaSlicer's C++ core compiled as a static library), and exports G-code directly to the iOS Files app.

No network calls. No cloud. Runs entirely on-device.

## NOTE

This entire project will be written by AI.

## Architecture

```
SwiftUI app
    └── ContentView.swift
         └── slicer_bridge.h / .cpp   ← thin C wrapper (Swift can't call C++ directly)
              └── libslic3r.a          ← PrusaSlicer core, cross-compiled for arm64
                   └── ~/ios-sysroot-sim/lib/
                        Boost, TBB, CGAL, GMP, MPFR, Qhull, LibBGCode,
                        heatshrink, Clipper2, zlib, libpng, expat, nlohmann_json, …
```

The XCFramework packages `libslic3r.a` so Xcode can consume it. The C bridge (`slicer_bridge.cpp`) is compiled as part of the app target and links everything together.

## Prerequisites

- macOS with Xcode 16+ installed (not just CLI tools — full Xcode)
- Apple Silicon Mac recommended (builds target `SIMULATORARM64` by default)
- Homebrew

Everything else (cmake, ninja, xcodegen, …) is installed by step 00.
CGAL 5.6.2 is downloaded from GitHub by step 13 — do **not** `brew install cgal`
(Homebrew ships CGAL 6.x which has an incompatible API).

## Build

```bash
# Clone this repo, then:
./build.sh
```

This runs 15 numbered steps in order. Each step is **idempotent** — re-running skips steps that are already done. To restart from a specific step:

```bash
./build.sh --from 7    # restart from Boost
./build.sh --only 3    # run only Clipper2 (toolchain smoke test)
```

### Steps

| # | Script | What it does | Time |
|---|--------|-------------|------|
| 0 | `00_prerequisites.sh` | `brew install cmake ninja xcodegen …` | ~1 min |
| 1 | `01_toolchain.sh` | Download `ios.toolchain.cmake` from leetal/ios-cmake | seconds |
| 2 | `02_prusaslicer.sh` | `git clone` PrusaSlicer + submodules + apply iOS patches | ~5 min |
| 3 | `03_clipper2.sh` | Build Clipper2 — **toolchain smoke test** | ~1 min |
| 4 | `04_eigen.sh` | Copy Eigen3 headers (no compilation) | ~1 min |
| 5 | `05_zlib.sh` | Build zlib | ~1 min |
| 6 | `06_libpng.sh` | Build libpng | ~1 min |
| 7 | `07_boost.sh` | Build Boost via b2 | **20–40 min** |
| 8 | `07b_boost_nowide.sh` | Build boost::nowide (from Boost source tree) | ~1 min |
| 9 | `08_tbb.sh` | Build oneTBB | ~5 min |
| 10 | `09_expat.sh` | Build libexpat | ~1 min |
| 11 | `09b_gmp.sh` | Build GMP (pure-C, no assembly) for CGAL exact arithmetic | ~5 min |
| 12 | `09c_mpfr.sh` | Build MPFR (multi-precision float) | ~3 min |
| 13 | `09d_cgal.sh` | Download + install CGAL 5.6.2 headers + cmake config | ~1 min |
| 14 | `09e_cereal.sh` | Install cereal headers + cmake config | seconds |
| 15 | `09f_qhull.sh` | Build Qhull (convex hull) | ~1 min |
| 16 | `09g_heatshrink.sh` | Build heatshrink (compression, needed by LibBGCode) | ~1 min |
| 17 | `09h_libbgcode.sh` | Build LibBGCode (Prusa binary gcode format) | ~2 min |
| 18 | `10_libslic3r.sh` | Build libslic3r from full PrusaSlicer tree | ~10 min |
| 19 | `10b_install_stub_headers.sh` | Install stub headers (seq, nlopt, nanosvg, bundled deps) | ~1 min |
| 20 | `11_xcframework.sh` | Package `libslic3r.a` as XCFramework | seconds |

All deps install into `~/ios-sysroot-sim/`. All source repos clone into `~/ios-sources/`.

**Note:** Steps 11–13 (GMP/MPFR/CGAL) were required because libslic3r uses CGAL for Voronoi diagrams in the Arachne variable-width perimeter algorithm — which is in the active FDM path. GMP is built with `--disable-assembly` (pure C) and `--enable-cxx` (C++ bindings).

## Open in Xcode

After `build.sh` completes:

```bash
cd app

# One-time: set your Apple Developer Team ID for code signing
cp project.local.yml.example project.local.yml
# Edit project.local.yml and replace XXXXXXXXXX with your Team ID.
# Find it with:
#   security find-identity -v -p codesigning | grep "Apple Development"
# It's the string in parentheses, e.g. "Apple Development: Your Name (XXXXXXXXXX)"
# project.local.yml is gitignored — never commit it.

xcodegen
open SlicePal.xcodeproj
```

Select the **iPhone simulator** target, hit **⌘R**. The app builds and runs in the simulator.

## App (v1 prototype)

Single screen. One button.

- Loads `cube.stl` (20×20×20 mm) from the app bundle
- Slices at 0.2 mm layer height, 20% gyroid infill, hardcoded Ender-class printer settings
- Writes `cube_0.20mm_20.gcode` to the app's Documents directory
- **Share button** opens the iOS Share Sheet — AirDrop, save to Files, send anywhere
- The app's Documents folder also appears directly in the **iOS Files app** (`UIFileSharingEnabled`)

## PrusaSlicer Modifications

libslic3r is built from the unmodified PrusaSlicer source tree with two categories of changes:

### CMake option: `SLIC3R_IOS`

Added to `CMakeLists.txt` and `src/libslic3r/CMakeLists.txt`. When `ON`:
- **CURL / OpenGL / GLEW / NLopt / OpenVDB** — skipped entirely (not used by FDM slicing)
- **Z3 / libseqarrange** — excluded from build (sequential arrangement is a GUI feature)
- **JPEG** — excluded (only used for gcode thumbnails, which are optional)
- **PrusaSlicer binary install** — skipped (iOS toolchain would treat it as a MACOSX_BUNDLE)

### Stub source files

Two small stub `.cpp` files are compiled instead of their JPEG/Z3-dependent originals:

| Stub file | Replaces | What it does |
|-----------|----------|-------------|
| `src/libslic3r/GCode/Thumbnails_ios_stub.cpp` | `Thumbnails.cpp` | Returns empty buffers — thumbnails in gcode are optional |
| `src/libslic3r/ArrangeHelper_ios_stub.cpp` | `ArrangeHelper.cpp` | `check_seq_conflict` returns `nullopt`; sequential arrange is never invoked in basic FDM |

### Stub headers in `~/ios-sysroot-sim/include/`

| Header | Why needed |
|--------|-----------|
| `libseqarrange/seq_interface.hpp` | `ArrangeHelper.hpp` is included by `Print.cpp`; stub provides Sequential types as forward-declared pointers without Z3 |
| `nlopt.h` | Included by `NLoptOptimizer.hpp` (SLA code); SLA is never called in FDM path |
| `nanosvg/nanosvg.h` | Included by `EmbossShape.hpp`; embossing is not in the slicing path |

## Known Friction Points

| Step | Likely issue | Fix |
|------|-------------|-----|
| Boost (07) | Build time ~30 min on first run | Let it run; subsequent runs skip via sentinel |
| GMP (11) | `--disable-assembly` makes it slower but portable to iOS simulator | No action needed; it's intentional |
| CGAL version | PrusaSlicer 2.7/2.8 uses CGAL 5.6.2 API; CGAL 6.x changed `property_map()` return type | Script installs CGAL 5.6.2 headers from source, not homebrew |
| libslic3r (14) | `Print::apply()` / `export_gcode()` signature may differ from cloned version | Check `git log` in `~/ios-sources/PrusaSlicer`; adjust the flagged lines in `slicer_bridge.cpp` |
| Xcode link | Missing `.a` symbols at link time | Verify `~/ios-sysroot-sim/lib/` has all expected files; cross-check `OTHER_LDFLAGS` in `app/project.yml` |

## Project Layout

```
SlicePal/
├── README.md
├── build.sh                          ← master build entry point (steps 0–20)
├── patches/
│   ├── prusaslicer_ios.patch         ← CMakeLists changes (SLIC3R_IOS option)
│   ├── ArrangeHelper_ios_stub.cpp    ← stub: no-op sequential arrange (no Z3)
│   └── Thumbnails_ios_stub.cpp       ← stub: empty thumbnails (no JPEG)
├── scripts/
│   ├── common.sh                     ← shared env vars + helpers
│   ├── 00_prerequisites.sh
│   ├── 01_toolchain.sh
│   ├── 02_prusaslicer.sh             ← clone + apply patches/
│   ├── 03_clipper2.sh
│   ├── 04_eigen.sh
│   ├── 05_zlib.sh
│   ├── 06_libpng.sh
│   ├── 07_boost.sh
│   ├── 07b_boost_nowide.sh
│   ├── 08_tbb.sh
│   ├── 09_expat.sh
│   ├── 09b_gmp.sh
│   ├── 09c_mpfr.sh
│   ├── 09d_cgal.sh                   ← downloads CGAL 5.6.2 from GitHub
│   ├── 09e_cereal.sh
│   ├── 09f_qhull.sh
│   ├── 09g_heatshrink.sh
│   ├── 09h_libbgcode.sh
│   ├── 10_libslic3r.sh
│   ├── 10b_install_stub_headers.sh   ← seq stub, nlopt.h, nanosvg, bundled deps
│   └── 11_xcframework.sh
└── app/
    ├── project.yml                   ← xcodegen spec (links ~40 static libs)
    └── SlicePal/
        ├── SlicePalApp.swift
        ├── ContentView.swift
        ├── slicer_bridge.h           ← C API visible to Swift
        ├── slicer_bridge.cpp         ← libslic3r wrapper
        ├── SlicePal-Bridging-Header.h
        └── Resources/
            └── cube.stl              ← 20mm test model
```

## Why Not Cura / Unity

**Cura (CuraEngine):** architected as a CLI process communicating over a socket — not embeddable. iOS prohibits spawning child processes and loading dynamic libraries at runtime.

**Unity:** adds 100 MB+ runtime overhead and conflicts with iOS's prohibition on dynamic code loading. SwiftUI + SceneKit achieves the same 3D viewing with zero overhead.

**libslic3r:** actual embeddable C++ library, not a CLI. Statically linkable. On A-series chips, slicing a simple model takes under a second.

## Roadmap

- [x] Build chain (all deps + libslic3r cross-compiled for iOS Simulator)
- [x] C bridge (load STL / slice / export G-code)
- [x] Single-screen SwiftUI prototype
- [x] G-code export via Share Sheet + Files app
- [x] Confirmed working: valid G-code produced on-device
- [ ] SceneKit 3D viewer with orbit/pan/zoom
- [ ] Model rotation (3-axis + snap-to-face) and scaling
- [ ] Printer profiles (bed size, nozzle diameter, start/end G-code)
- [ ] Material sub-profiles (temps, retraction, fan, flow rate)
- [ ] Slicing progress bar with cancellation
- [ ] Device (non-simulator) build — rebuild deps with `PLATFORM=OS64`
- [ ] Support structures
- [ ] G-code layer preview

## License

libslic3r is AGPL-3.0. This app, as a derivative work, is also AGPL-3.0.
