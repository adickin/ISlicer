# IosSlicer — Feature Progress

## To Do

### High Priority (v1 polish)
- [ ] **Device build** — `build_device.sh` in progress; `common.sh` now platform-aware; `project.yml` uses `$(IOS_SYSROOT)` with SDK conditionals; `11_xcframework.sh` creates dual slice when both sysroots exist

### Viewer
- [ ] **SceneKit 3D viewer** — load + display the STL mesh with orbit/pan/zoom gestures
- [ ] **Layer preview** — parse and visualize gcode layers (lines by extrusion type)
- [ ] **Print time + filament estimate** — read from gcode comments after slicing

### Slicing Settings
- [ ] **Layer height picker** — 0.1 / 0.15 / 0.2 / 0.3 mm
- [ ] **Infill density slider** — 5–100%
- [ ] **Infill pattern picker** — gyroid, grid, honeycomb, lines
- [ ] **Support structures toggle** — on/off; auto vs. manual placement
- [ ] **Brim / skirt / raft** — adhesion options

### Printer Profiles
- [ ] **Profile model** — bed size, nozzle diameter, max height, start/end gcode
- [ ] **Built-in profiles** — Prusa MK4, Bambu X1, Ender 3, Voron 2.4
- [ ] **Custom profile editor**
- [ ] **Profile persistence** — save/load from app Documents

### Material Profiles
- [ ] **Material model** — temps (hotend + bed), retraction, fan curve, flow rate, name
- [ ] **Built-in materials** — PLA, PETG, ABS, TPU
- [ ] **Custom material editor**

### Model Manipulation
- [ ] **Rotation** — 3-axis rotate with snap-to-face
- [ ] **Scale** — uniform + per-axis, with "fit to bed" shortcut
- [ ] **Auto-orient** — rotate to minimize support area
- [ ] **Multi-model** — place and arrange multiple objects on the bed
- [ ] **Cut tool** — slice model at a Z height (useful for models taller than the printer)

### Infrastructure
- [ ] **Proper bundleId** — replace `com.yourname` placeholder in `project.yml`
- [ ] **App icon + launch screen**
- [ ] **iPad layout** — split-view with settings panel
- [ ] **Haptic feedback** on slice complete
- [ ] **iCloud Drive sync** for profiles and recent files
- [ ] **TestFlight distribution**

## Far future

- [ ] direct from thingverse or other model hubs to sliced gcode.  i want it just pass the url, app downloads the zip and auto slices everything.


## Completed

### Build Chain
- [x] iOS CMake toolchain (leetal/ios-cmake, SIMULATORARM64)
- [x] Clipper2 — polygon clipping
- [x] Eigen3 — linear algebra headers
- [x] zlib
- [x] libpng
- [x] Boost (b2 cross-compile, static runtime, ~20 libs)
- [x] boost::nowide — UTF-8 file I/O on all platforms
- [x] boost::locale stub — safe no-op (only used in preset loading, not slicing)
- [x] oneTBB — task-based parallelism
- [x] libexpat — XML parsing
- [x] GMP 6.3.0 — exact arithmetic (pure-C, no assembly, C++ bindings enabled)
- [x] MPFR 4.2.2 — multi-precision float (depends on GMP)
- [x] CGAL 5.6.2 — computational geometry (headers + cmake config pointing to our GMP/MPFR)
- [x] cereal — serialization headers
- [x] Qhull — convex hull (custom iOS CMakeLists, no shared lib export issues)
- [x] heatshrink — data compression (custom wrapper, no executable target)
- [x] LibBGCode — Prusa binary gcode format
- [x] nlohmann/json — header-only JSON
- [x] NanoSVG — header-only SVG (fltk fork)
- [x] NLopt 2.5.0 — header-only for compilation (SLA only, not called in FDM path)
- [x] libslic3r — PrusaSlicer core, cross-compiled for arm64-apple-ios-simulator
- [x] XCFramework packaging of libslic3r.a

### PrusaSlicer Patches
- [x] `SLIC3R_IOS` cmake option added to root CMakeLists
- [x] CURL, OpenGL, GLEW, NLopt, OpenVDB gated behind `SLIC3R_IOS`
- [x] Z3 / libseqarrange excluded from build (sequential arrange is GUI-only)
- [x] JPEG excluded (thumbnails are optional in gcode)
- [x] `ArrangeHelper_ios_stub.cpp` — satisfies linker without Z3
- [x] `Thumbnails_ios_stub.cpp` — satisfies linker without JPEG
- [x] Stub `seq_interface.hpp` header in sysroot (Sequential types, no Z3)

### App
- [x] SwiftUI single-screen UI
- [x] C bridge (`slicer_bridge.h` / `.cpp`) — Swift ↔ libslic3r
- [x] STL load from app bundle (`cube.stl`)
- [x] FDM slicing with hardcoded settings (0.2 mm / 20% gyroid / Ender-class printer)
- [x] G-code export to app Documents directory
- [x] Share Sheet for AirDrop / Files / send anywhere
- [x] Files app integration (`UIFileSharingEnabled`)
- [x] Xcode project via xcodegen (`app/project.yml`)
- [x] Confirmed: valid G-code produced on-device in iOS Simulator
- [x] Real STL file picker — `UIDocumentPickerViewController`; file copied to temp dir before slicing
- [x] Slicing progress indicator — `Print::set_status_callback` → `ProgressView(value:)`
- [x] Slicing cancellation — `slicer_cancel()` calls `Print::cancel()`; returns to idle cleanly
- [x] Error UI — all failures shown via SwiftUI `.alert` modal

