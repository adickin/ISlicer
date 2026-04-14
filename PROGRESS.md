# IosSlicer — Feature Progress

## To Do

### High Priority (v1 polish)
- [ ] **Device build** — `build_device.sh` in progress; `common.sh` now platform-aware; `project.yml` uses `$(IOS_SYSROOT)` with SDK conditionals; `11_xcframework.sh` creates dual slice when both sysroots exist

### Viewer
- [ ] **Layer preview** — parse and visualize gcode layers (lines by extrusion type)
- [ ] **Print time + filament estimate** — read from gcode comments after slicing
- [ ] **Wireframe toggle** — overlay wire edges on the mesh
- [ ] **Overhang highlight** — colour faces by angle to indicate support need
- [ ] **Face normal colour mode** — shade by surface normal direction

### Slicing Profiles
Plan: `Plans/slicing_profiles.md`

**Data model + persistence**
- [ ] `InfillPattern` enum — gyroid, grid, honeycomb, lines, triangles, cubic, adaptive cubic, lightning (with `bridgeInt` mapping to PrusaSlicer's `InfillPattern` enum)
- [ ] `SupportStyle` enum — Normal (Snug) / Tree (Auto)
- [ ] `SupportPlacement` enum — Everywhere / Touching Build Plate Only
- [ ] `BrimType` enum — None / Outer Only / Inner Only / Outer and Inner (with `bridgeInt`)
- [ ] `SliceProfile` struct — all settings below, Codable
- [ ] `SliceProfileStore` — `@MainActor ObservableObject`; JSON load/save; seed version bump
- [ ] `BuiltInSliceProfiles` — Draft (0.3 mm), Standard (0.2 mm), Fine (0.1 mm)

**Settings covered by SliceProfile:**
- Layer height, first layer height
- Wall count (perimeters), horizontal expansion (xy_size_compensation)
- Top/bottom layers, min top/bottom thickness
- Infill density (%), infill pattern
- Speed: print (perimeter), infill, travel, first layer
- Support: generate, style, placement, overhang angle, horizontal expansion, use towers
- Build plate adhesion: None / Skirt (loops + distance) / Brim (type + width) / Raft (layers)

**C bridge**
- [ ] `SlicerSliceConfig` C struct + `slicer_apply_slice_config()` in `slicer_bridge.h/.cpp`
- [ ] Refactor bridge config accumulation — merge printer + slice configs before `print.apply()`

**UI**
- [ ] `SliceProfileEditorView` — Form with Layers / Walls / Top-Bottom / Infill / Speed / Support / Adhesion sections
- [ ] `SliceProfilePickerView` — list with summary subtitle (layer height · infill % · speed · supports on/off)
- [ ] `ContentView` — "Profile: [Name]" row, calls `slicer_apply_slice_config` before slicing
- [ ] `IosSlicerApp` — `SliceProfileStore` as second `@StateObject`, injected as `.environmentObject`

### Printer Profiles
- [ ] **Additional built-in profiles** — Prusa MK4, Bambu X1C, Voron 2.4
- [ ] **Multi-extruder bridge** — `SlicerPrinterConfig` currently only passes extruder 0; extend to pass per-extruder arrays for nozzle/filament diameter and offsets
- [ ] **Reset profile to default** — "Reset to built-in defaults" button in profile editor for built-in profiles

### Material Profiles
*Retraction, Z-hop, and cooling/fan settings live here — not in slice profiles — because they are material-dependent (PrusaSlicer filament profile architecture).*

**Data model + persistence**
- [ ] `MaterialProfile` struct — Codable; maps to PrusaSlicer filament config keys
  - Name, filament diameter (mm)
  - Hotend temperature — first layer + other layers (`first_layer_temperature`, `temperature`)
  - Bed temperature — first layer + other layers (`first_layer_bed_temperature`, `bed_temperature`)
  - Flow rate / extrusion multiplier (%; `extrusion_multiplier`)
  - Enable retraction (`retract_length > 0` gate in bridge)
  - Retraction length (mm; `retract_length`)
  - Retraction speed (mm/s; `retract_speed`)
  - Z-hop when retracted (mm; `retract_lift`)
  - Min travel before retraction (mm; `retract_before_travel`)
  - Enable cooling (`cooling`)
  - Min fan speed (%; `min_fan_speed`)
  - Max fan speed (%; `max_fan_speed`)
  - Bridge fan speed (%; `bridge_fan_speed`)
  - Disable fan for first N layers (`disable_fan_first_layers`)
- [ ] `MaterialProfileStore` — same pattern as `ProfileStore` / `SliceProfileStore`
- [ ] `BuiltInMaterialProfiles` — PLA, PETG, ABS, TPU with sensible defaults

**C bridge**
- [ ] `SlicerMaterialConfig` C struct + `slicer_apply_material_config()` in `slicer_bridge.h/.cpp`

**UI**
- [ ] `MaterialProfileEditorView` — Form with Temperatures / Retraction / Cooling sections
- [ ] `MaterialProfilePickerView` — list with summary subtitle (name · temp · retraction on/off)
- [ ] `ContentView` — "Material: [Name]" row, calls `slicer_apply_material_config` before slicing

### Model Manipulation
- [ ] **Rotation** — 3-axis rotate with snap-to-face
- [ ] **Scale** — uniform + per-axis, with "fit to bed" shortcut
- [ ] **Auto-orient** — rotate to minimize support area
- [ ] **Multi-model** — place and arrange multiple objects on the bed
- [ ] **Cut tool** — slice model at a Z height (useful for models taller than the printer)
- [ ] **Model placement UI** — move / rotate / scale model interactively in the 3D viewer

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

### Printer Profiles (2026-04-13)
- [x] `GCodeFlavor` enum — 12 flavors with `bridgeInt` mapping to PrusaSlicer's `GCodeFlavor` enum order
- [x] `BuildPlateShape` — rectangular / circular
- [x] `ExtruderProfile` — nozzle diameter, material diameters, X/Y offset, fan number, change duration, per-extruder start/end gcode
- [x] `PrinterProfile` — full machine + printhead + extruder settings, Codable
- [x] `BuiltInProfiles` — Ender 3 S1 seeded with correct PrusaSlicer placeholder syntax (`{first_layer_temperature[0]}` etc.; `{machine_depth}` hardcoded to 220 — no PrusaSlicer equivalent)
- [x] `ProfileStore` — `@MainActor ObservableObject`; JSON load/save; seed version bump forces re-seed when built-in profiles change
- [x] `GCodeEditorView` — reusable bordered monospaced TextEditor with copy button
- [x] `PrinterProfileEditorView` — Form with Name / Machine / G-Code / Printhead / per-Extruder sections
- [x] `ProfilePickerView` — list with circle-checkmark select, row-tap to edit, swipe-to-delete, + button
- [x] `slicer_bridge` — `SlicerPrinterConfig` C struct + `slicer_apply_printer_config()`; `kFlavorMap[]` keeps Swift `bridgeInt` and C++ enum in sync
- [x] `ContentView` — profile row shows active printer name; "No Printer Selected" alert guards slice; `applyPrinterProfile()` called before every slice
- [x] `IosSlicerApp` — `ProfileStore` created as `@StateObject`, injected as `.environmentObject`, loaded via `.task`

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
- [x] **SceneKit 3D viewer** — `STLParser.swift` (binary + ASCII STL → `SCNGeometry`, flat normals, unit-box normalisation); `STLSceneView.swift` (`SCNView` with orbit-turntable camera control, print-bed grid, XYZ axis gizmo); mesh rotated −90° around X to convert STL Z-up to SceneKit Y-up (Cura convention: X=right/red, Y=forward/green, Z=up/blue); sample STLs copied to app Documents on first launch
