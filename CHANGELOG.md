# Changelog

All notable changes to PalmSlice, harvested from [PROGRESS.md](PROGRESS.md) and commit history. Dates reflect when a feature was completed, not necessarily committed. Entries are grouped by date, most recent first.

## 2026-09-12

- Live output filename preview — the output filename field's placeholder shows the exact `.gcode` name that will be saved (model name + layer height + infill %) instead of a generic "(auto)" label; naming logic shared between the preview and the actual save path via `autoOutputStem()`
- First-launch EULA — beta-software / no-liability disclaimer shown once via `hasAcceptedEULA`; Accept continues, Decline exits the app
- About & Licenses moved to a floating (i) button in the bottom-right corner, above the collapsed slice panel
- README "Tested Printers" section added, listing real-world print validation (Ender 3 S1)

## 2026-09-01

- TestFlight build 1.0 (1) archived, signed, and uploaded to App Store Connect
- App Store Connect app record created (bundle ID `com.adickin.PalmSlice`)
- Privacy policy added (`PRIVACY.md`) — the app collects no data
- In-app About/Credits screen (`AboutView.swift`) — links to source repo, AGPL-3.0 license, privacy policy, and third-party license table
- `PalmSliceTests` XCTest target added — 15 tests covering profile Codable round-trips, built-in profile sanity, bridge-int enum uniqueness, and gcode parsing

## 2026-08-19

- Device (non-simulator) build confirmed working — `build_device.sh` populates `~/ios-sysroot-dev`; `libslic3r.xcframework` carries both `ios-arm64` and `ios-arm64-simulator` slices; Debug and Release both build clean for the `iphoneos` SDK

## 2026-04-18

- Interactive 3D translate gizmo — world-aligned X/Y/Z arrows follow the model; "Move" overlay button enters transform mode; drag an arrow to translate along that axis

## 2026-04-17

- Transform controls — `ModelTransform` state (position/rotation/scale) with a `TransformPanelView` sheet (Move / Rotate / Scale sections)
- Snap-to-face ("Lay Flat") — picks the largest downward-facing face via mesh normals + area weighting, converts to SceneKit Euler angles via quaternion
- Fit to bed / Center / Drop to bed helper buttons

## 2026-04-15

- Print time + filament estimate parsed from PrusaSlicer's gcode comments, shown in the status row
- Wireframe toggle for the 3D viewer
- Overhang highlight color mode (red/orange/yellow by downward-facing angle)
- Face normal color mode (normal XYZ mapped to RGB)
- Layer preview — full PrusaSlicer gcode parser (`GCodeParser.swift`) with a layer slider and per-extrusion-type line colors
- Material Profiles — `MaterialProfile` (filament, temperatures, retraction, cooling/fan), `MaterialProfileStore`, built-in PLA/PETG/ABS/TPU profiles, editor and picker UI, `slicer_apply_material_config()` bridge call

## 2026-04-13

- Slicing Profiles — `SliceProfile` (layers, walls, infill, speed, supports, adhesion), built-in Draft/Standard/Fine profiles, editor/picker/help UI, `slicer_apply_slice_config()` bridge call
- Printer Profiles — `PrinterProfile` (machine, printhead, per-extruder), built-in Ender 3 S1 profile, editor/picker UI, `slicer_apply_printer_config()` bridge call

## Foundational

Build chain, PrusaSlicer patches, and the original v1 app prototype — no longer individually dated, see [PROGRESS.md](PROGRESS.md) for the full itemized list.

- Full iOS cross-compilation of the dependency chain (Boost, TBB, CGAL, GMP, MPFR, Qhull, LibBGCode, Clipper2, zlib, libpng, expat, nlohmann/json, cereal, heatshrink) and libslic3r itself, packaged as an XCFramework
- PrusaSlicer patched with a `SLIC3R_IOS` CMake option gating out CURL/OpenGL/GLEW/NLopt/OpenVDB/Z3/JPEG, plus stub source files and headers so the FDM path builds without them
- SwiftUI single-screen prototype: C bridge (`slicer_bridge.h`/`.cpp`), STL load from bundle, hardcoded-settings FDM slicing, G-code export to Documents + Share Sheet + Files app integration
- Real STL file picker, slicing progress indicator, cancellation, and error alerts
- SceneKit 3D viewer (`STLParser.swift`, `STLSceneView.swift`) with orbit-turntable camera, print-bed grid, and XYZ axis gizmo
