# IosSlicer — Feature Progress

## To Do

### High Priority (v1 polish)
- [ ] **Device build** — `build_device.sh` in progress; `common.sh` now platform-aware; `project.yml` uses `$(IOS_SYSROOT)` with SDK conditionals; `11_xcframework.sh` creates dual slice when both sysroots exist

### Viewer
_(all items complete — see Plans/viewer_features.md)_

### Printer Profiles
- [ ] **Additional built-in profiles** — Prusa MK4, Bambu X1C, Voron 2.4
- [ ] **Multi-extruder bridge** — `SlicerPrinterConfig` currently only passes extruder 0; extend to pass per-extruder arrays for nozzle/filament diameter and offsets
- [ ] **Reset profile to default** — "Reset to built-in defaults" button in profile editor for built-in profiles

### Slicing Profiles
- [ ] **Additional speed settings** — outer perimeter speed, small perimeter speed, bridge speed, top solid infill speed (currently only the 4 main speeds are exposed; all others use PrusaSlicer defaults)
- [ ] **Reset profile to default** — "Reset to built-in defaults" button for built-in slice profiles (Draft / Standard / Fine)
- [ ] **Seam position** — aligned / nearest / random (`seam_position` key)
- [ ] **Extrusion width overrides** — per-feature extrusion width (perimeter, infill, top solid) for fine-tuning on non-standard nozzle sizes


### Model Manipulation
Plan: `Plans/model_manipulation.md`
- [x] **Transform controls** — `ModelTransform` state (positionMM / rotationDeg / scale); `pivotNode` in `STLSceneView` applies transform live; `TransformPanelView` sheet with Move / Rotate / Scale sections (2026-04-17)
- [x] **Snap-to-face** — "Lay Flat" button in rotate section; picks largest downward-facing face via `STLMeshInfo` normals + area weighting; converts to SceneKit Euler angles via quaternion (2026-04-17)
- [x] **Fit to bed / Center / Drop to bed** — helper buttons in Move and Scale sections; "Fit to Bed" scales to 90% of bed footprint (2026-04-17)
- [x] **Interactive 3D translate gizmo** — world-aligned X/Y/Z arrows follow model; tap "Move" overlay button to enter transform mode (disables orbit); drag an arrow to translate along that axis; gizmo scales with model; "Orbit" button returns to camera control (2026-04-18)
- [ ] **Auto-orient** — rotate to minimize support area; scores candidate rotations by overhang (Phase 6)
- [ ] **Cut tool** — Z-height slider + live cut-plane preview; `slicer_cut_at_z` C bridge call (Phase 7)
- [ ] **Multi-model** — `[ModelInstance]` state, add/remove/select models, auto-arrange on bed (Phase 8)

### Infrastructure
- [ ] **Proper bundleId** — replace `com.yourname` placeholder in `project.yml`
- [ ] **App icon + launch screen**
- [ ] **iPad layout** — split-view with settings panel
- [ ] **Haptic feedback** on slice complete
- [ ] **iCloud Drive sync** for profiles and recent files
- [ ] **TestFlight distribution**

## Far future

- [ ] direct from thingverse or other model hubs to sliced gcode.  i want it just pass the url, app downloads the zip and auto slices everything.
- 

## Completed

### Viewer (2026-04-15)
Plan: `Plans/viewer_features.md`
- [x] **Print time + filament estimate** — `parseGCodeStats()` in `ContentView` scans PrusaSlicer's `; estimated printing time (normal mode) =` and `; filament used [g] =` comments from the exported gcode; displayed in status row + collapsed panel subtitle
- [x] **Wireframe toggle** — `STLParser.buildGeometry` always emits a second `SCNGeometryElement` of type `.line` (3 edges per triangle); `STLSceneView.showWireframe` toggles visibility via `materials[1].transparency`; floating button in viewer overlay
- [x] **Overhang highlight** — `ViewerColorMode.overhang` mode in `STLParser`; per-vertex `SCNGeometrySource` with `.color` semantic; faces with `n.z < -0.5` (STL space) = red-orange, `n.z < 0` = yellow, upward = grey; `.constant` lighting
- [x] **Face normal colour mode** — `ViewerColorMode.faceNormal`; normal XYZ mapped to RGB via `(n+1)/2`; same per-vertex colour source path as overhang; cycled via same overlay button
- [x] **Layer preview** — `GCodeParser.swift`: full PrusaSlicer gcode parser (`parseGCode`) emitting `[GCodeLayer]` with typed `GCodeMove` (`ExtrusionType`); `GCodeSceneView.swift`: async geometry build (Task.detached), per-type line colours, bed grid + axes; `ContentView`: layer slider overlay, toggle button, parses layers immediately after export

### Material Profiles (2026-04-15)
Plan: `Plans/material_profiles.md`
- [x] `MaterialProfile` struct — Codable; filament diameter, temperatures (first layer + other, hotend + bed), extrusion multiplier, retraction (length/speed/restart extra/Z-hop/min travel), cooling/fan (min/max/bridge speed, disable-first-N-layers, fan-below-layer-time, slowdown-below-layer-time, min-print-speed)
- [x] `MaterialProfileStore` — same `@MainActor ObservableObject` pattern as `ProfileStore` / `SliceProfileStore`; JSON to `material_profiles.json`; seed version bump
- [x] `BuiltInMaterialProfiles` — PLA, PETG, ABS, TPU with sensible defaults including cooling/retraction differences per material
- [x] `SlicerMaterialConfig` C struct + `slicer_apply_material_config()` in `slicer_bridge.h/.cpp`; all per-extruder keys wrapped in single-element vectors; `retract_length=0` disables retraction natively
- [x] `MaterialProfileEditorView` — Form with Name / Filament & Temperature / Retraction / Cooling sections; sub-fields hidden behind toggles
- [x] `MaterialProfilePickerView` — circle-checkmark select, row-tap to edit, swipe-to-delete, + button
- [x] `ContentView` — "Material" row (drop icon) below slice profile row; `applyMaterialProfile()` called before slicing (optional — slicing proceeds with bridge defaults if no profile selected); call order: printer → material → slice
- [x] `IosSlicerApp` — `materialProfileStore` as third `@StateObject`, injected as `.environmentObject`, loaded in `.task`

### Slicing Profiles (2026-04-13)
Plan: `Plans/slicing_profiles.md`
- [x] `InfillPattern` enum — gyroid, grid, honeycomb, lines, triangles, cubic, adaptive cubic, lightning; `bridgeInt` ordinals verified against `PrintConfig.hpp` (gyroid=12, grid=4, etc.)
- [x] `SupportStyle` enum — Normal (Snug) / Tree (Organic); `bridgeInt` → smsSnug(1) / smsOrganic(3)
- [x] `SupportPlacement` enum — Everywhere / Touching Build Plate Only
- [x] `BrimType` enum — Outer Only / Inner Only / Outer and Inner; `bridgeInt` → btOuterOnly(1) / btInnerOnly(2) / btOuterAndInner(3)
- [x] `AdhesionType` enum — None / Skirt / Brim / Raft (top-level wrapper; maps to PrusaSlicer's separate `brim_type` / `skirts` / `raft_layers` keys)
- [x] `SliceProfile` struct — all settings Codable; `pickerSubtitle` computed property (layer height · infill % · speed · supports on/off)
- [x] `SliceProfileStore` — `@MainActor ObservableObject`; JSON load/save to `slice_profiles.json`; seed version bump
- [x] `BuiltInSliceProfiles` — Draft (0.3 mm / 15% grid / 80 mm/s), Standard (0.2 mm / 20% gyroid / 60 mm/s), Fine (0.1 mm / 20% gyroid / 40 mm/s)
- [x] `SlicerSliceConfig` C struct + `slicer_apply_slice_config()` — sets all 26 slice settings on `DynamicPrintConfig`; adhesion type fan-out to correct PrusaSlicer keys; speed type bug fixed (`perimeter_speed` / `infill_speed` are `ConfigOptionFloat`, not `ConfigOptionFloatOrPercent`)
- [x] `slice_config_applied` flag on `SlicerContext` — prevents `slicer_slice_with_progress` legacy params from overwriting the slice config
- [x] `SliceProfileEditorView` — Form with Name / Layers / Walls / Top-Bottom / Infill / Speed / Support / Adhesion sections; support sub-options revealed when generate support is on; adhesion sub-options switch by type; help button at bottom
- [x] `SliceProfilePickerView` — circle-checkmark select, row-tap to edit, swipe-to-delete, + button; subtitle shows live profile summary
- [x] `SliceProfileHelpView` — full plain-English descriptions for every setting, organized by section, presented as a sheet from the editor
- [x] `ContentView` — "Slice Profile" row (slider icon) alongside printer row; guards slice if no profile selected; calls `slicer_apply_slice_config` before every slice; status subtitle and gcode filename reflect the active profile
- [x] `IosSlicerApp` — `SliceProfileStore` as second `@StateObject`, injected as `.environmentObject`, loaded in `.task`

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
