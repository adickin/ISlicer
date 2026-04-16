# Viewer Features — Implementation Plan

## Goal

Extend the existing SceneKit-based 3D viewer (`STLSceneView` / `STLParser`) with five new capabilities listed in PROGRESS.md:

1. **Wireframe toggle** — overlay wire edges on the mesh
2. **Overhang highlight** — colour faces by angle to indicate support need
3. **Face normal colour mode** — shade by surface normal direction
4. **Print time + filament estimate** — read from gcode comments after slicing
5. **Layer preview** — parse and visualise gcode layers (lines by extrusion type)

Features 1–3 are pure viewer enhancements (no new files, no bridge changes). Feature 4 is a gcode-parse step wired into the existing slice pipeline. Feature 5 is the most complex: a new gcode parser + a separate SceneKit scene.

---

## 1. Wireframe Toggle

### Approach

SceneKit does not expose a built-in wireframe mode on `SCNGeometry`. The cleanest iOS-compatible approach is to add a second `SCNGeometryElement` of primitive type `.line` alongside the existing `.triangles` element, rendered with a black/dark constant material. Toggle by showing/hiding the line element's material (set its `transparency` to 0 or 1).

An alternative — toggling `SCNNode.geometry` between two pre-built geometries — is simpler but doubles memory. Prefer the dual-element approach.

### Changes

**`STLParser.swift`**

Add a second build path that emits both a triangles element and a lines element:

```swift
/// Builds SCNGeometry with an optional wireframe element.
func buildGeometry(
    triangles: [(v0: SIMD3<Float>, v1: SIMD3<Float>, v2: SIMD3<Float>)],
    wireframe: Bool = false
) -> SCNGeometry
```

When `wireframe: true`, add a `SCNGeometryElement` of type `.line` using the same vertex buffer.  Each triangle contributes three line segments (6 index entries: 0-1, 1-2, 2-0).

The wireframe material uses `.constant` lighting and `diffuse.contents = UIColor(white: 0, alpha: 0.45)`.

**`STLSceneView.swift`**

Add a `var showWireframe: Bool` property. In `updateUIView`, after updating `meshNode.geometry`, call a helper:

```swift
private func applyWireframe(_ geo: SCNGeometry, show: Bool) {
    // materials[0] = solid surface, materials[1] = wireframe lines
    guard geo.materials.count > 1 else { return }
    geo.materials[1].transparency = show ? 1.0 : 0.0
}
```

**`ContentView.swift`**

Add `@State private var showWireframe = false` and a toolbar or overlay button (a grid icon) that toggles it. Pass `showWireframe` into `STLSceneView`.

### File Summary

| File | Action |
|------|--------|
| `STLParser.swift` | Edit — emit lines element in `buildGeometry` |
| `STLSceneView.swift` | Edit — add `showWireframe` prop + `applyWireframe` helper |
| `ContentView.swift` | Edit — add toggle state + overlay button |

---

## 2. Overhang Highlight

### Approach

For each triangle, compute the angle between its outward face normal and the global up vector (0, 1, 0 in SceneKit world space, which maps to STL Z-up after the -90° rotation). If the angle from vertical exceeds a threshold (default 45°) the face is considered an overhang and coloured red/orange; shallower faces use the normal grey.

The colour is baked into per-vertex colour data (`SCNGeometrySource` with semantic `.color`) so no shader is needed.

### Changes

**`STLParser.swift`**

Add `buildGeometry(triangles:colorMode:)` with a `ColorMode` enum:

```swift
enum ViewerColorMode {
    case solid          // current behaviour — flat grey PBR
    case overhang       // grey + red tint for faces > 45° from vertical
    case faceNormal     // RGB mapped from normalised normal direction
}
```

When `colorMode == .overhang`:
- For each triangle normal (already computed), compute `angle = acos(clamp(dot(n, up), -1, 1))` where `up` is the world-up direction transformed back through the mesh rotation.
- In STL space, "up" = (0, 0, 1). After normalising the face normal `n` (already in STL space pre-rotation), `overhang = n.z < cos(45°)`.
- Assign colour: `overhang ? UIColor(red:1, green:0.35, blue:0.1, alpha:1) : UIColor(white:0.82, alpha:1)`.
- Add the colour as a `SCNGeometrySource(data:semantic:.color, ...)`.
- Switch material `lightingModel` to `.lambert` (colours are vertex-driven; PBR ignores vertex colour).

**`STLSceneView.swift`**

Add `var colorMode: ViewerColorMode` property. Pass it to `parseSTL` on geometry rebuild. Changing `colorMode` should force a geometry rebuild (`updateUIView` already checks `lastGeometry !==`; invalidate by setting `lastGeometry = nil` when `colorMode` changes).

**`ContentView.swift`**

Add `@State private var viewerColorMode: ViewerColorMode = .solid` and a segmented picker or a menu button in the viewer overlay. Values: Solid / Overhang / Normals.

### File Summary

| File | Action |
|------|--------|
| `STLParser.swift` | Edit — add `ViewerColorMode`, per-vertex colour source |
| `STLSceneView.swift` | Edit — `colorMode` prop, invalidate geometry on mode change |
| `ContentView.swift` | Edit — mode picker in viewer overlay |

---

## 3. Face Normal Colour Mode

Shares the same infrastructure as overhang highlight (same `ViewerColorMode` enum, same per-vertex colour path in `buildGeometry`).

When `colorMode == .faceNormal`:
- Face normal `n` is already in STL space: `x ∈ [-1,1]`, `y ∈ [-1,1]`, `z ∈ [-1,1]`.
- Map to colour: `r = (n.x + 1)/2`, `g = (n.y + 1)/2`, `b = (n.z + 1)/2`.
- Assign the same colour to all three vertices of the triangle.
- Material: `.constant` lighting (no shading, pure colour).

No additional files beyond those listed in §2.

---

## 4. Print Time + Filament Estimate

### Approach

After a successful slice, parse the gcode file for PrusaSlicer comment lines that contain the estimates. PrusaSlicer writes these near the end of the file:

```
; estimated printing time (normal mode) = 1h 23m 45s
; filament used [g] = 12.34
```

Parse in Swift — no bridge change needed; the gcode is already on disk.

### Changes

**New file: `GCodeStats.swift`**

```swift
struct GCodeStats {
    var printTime: String?    // human-readable, e.g. "1h 23m 45s"
    var filamentGrams: String? // e.g. "12.34 g"
}

func parseGCodeStats(url: URL) -> GCodeStats {
    // Read last ~4 KB of file (estimates are at the end)
    // Scan lines for:
    //   "; estimated printing time (normal mode) = "
    //   "; filament used [g] = "
}
```

**`ContentView.swift`**

`SliceState.done` already carries `printTime: String?` and `filamentG: String?`. Wire `parseGCodeStats` into `runSlice()` right after `slicer_export_gcode` succeeds:

```swift
let stats = parseGCodeStats(url: gcodeURL)
await MainActor.run {
    state = .done(gcodeURL: gcodeURL,
                  printTime: stats.printTime,
                  filamentG: stats.filamentGrams)
}
```

The existing bottom panel already renders these values when non-nil — no UI changes needed.

### File Summary

| File | Action |
|------|--------|
| `GCodeStats.swift` | **New** — parser for estimate comments |
| `ContentView.swift` | Edit — call `parseGCodeStats` after export, populate `SliceState.done` |

---

## 5. Layer Preview

### Approach

After slicing, the user can tap a "Layer Preview" button to switch from the STL viewer to a per-layer gcode visualisation. Each layer is rendered as coloured line segments grouped by extrusion type (perimeters, infill, travel, support).

This is the most complex feature. It requires:
1. A gcode parser that emits per-layer, per-type line segment arrays.
2. A new `GCodeSceneView` (replaces `STLSceneView` in the layer preview mode).
3. A layer slider to navigate between layers.

### 5.1 Gcode Parser (`GCodeParser.swift`)

```swift
enum ExtrusionType {
    case perimeter, externalPerimeter, infill, solidInfill, support, travel, other
}

struct GCodeMove {
    var from: SIMD3<Float>
    var to:   SIMD3<Float>
    var type: ExtrusionType
}

struct GCodeLayer {
    var z: Float
    var moves: [GCodeMove]
}

func parseGCode(url: URL) -> [GCodeLayer]
```

Parse rules:
- `;TYPE:` comments set current `ExtrusionType` (PrusaSlicer emits these before each feature group).
- `G1 Z<n>` or `;LAYER_CHANGE` advances to a new layer at height `z`.
- `G1 X<x> Y<y> [Z<z>] [E<e>]`: if `E > 0` it is an extrusion move; if `E` is absent or `≤ 0` it is a travel.
- Track current XYZ position; relative/absolute mode (`G90`/`G91`).

### 5.2 Layer Scene View (`GCodeSceneView.swift`)

A `UIViewRepresentable` wrapping an `SCNView`, similar to `STLSceneView`:
- One `SCNNode` per layer (hidden/visible based on `currentLayer`).
- Lines coloured by `ExtrusionType`:

| Type | Colour |
|------|--------|
| External perimeter | Orange `#FF8C00` |
| Perimeter | Yellow `#FFD700` |
| Solid infill | Red `#FF4444` |
| Infill | Cyan `#00BFFF` |
| Support | Light purple `#CC99FF` |
| Travel | Transparent dark grey (hidden by default) |
| Other | White |

- Print bed grid and axes (reuse `makePrintBedNode` / `makeAxesNode` from `STLSceneView`; extract them to a shared file or duplicate).
- `var currentLayer: Int` — only the node for that layer index is visible; nodes above are hidden.
- Performance: for models with many layers, build nodes lazily (only build the current ±2 layers on scroll). For v1 it's acceptable to build all at parse time.

### 5.3 Layer Slider UI

In `ContentView`, when `state == .done` and layer preview mode is active:
- Replace `STLSceneView` with `GCodeSceneView`.
- Overlay a `Slider` at the bottom (above the panel) for layer index.
- Show "Layer N / Total" label.
- A "Back to Model" button exits layer preview.

```swift
@State private var showLayerPreview = false
@State private var parsedLayers: [GCodeLayer] = []
@State private var currentLayerIndex: Int = 0
```

After slice completes, parse layers in background:
```swift
Task.detached {
    let layers = parseGCode(url: gcodeURL)
    await MainActor.run { parsedLayers = layers }
}
```

### File Summary

| File | Action |
|------|--------|
| `GCodeParser.swift` | **New** — per-layer, per-type move parser |
| `GCodeSceneView.swift` | **New** — SceneKit view for gcode line segments |
| `ContentView.swift` | Edit — layer preview state + toggle button + slider overlay |

---

## Implementation Order

1. **Print time + filament** (§4) — pure Swift, touches only `ContentView` + one new file; zero risk; confirms gcode is being written correctly. Already partially wired (`SliceState.done` carries the fields).
2. **Wireframe toggle** (§1) — additive change to `STLParser` + `STLSceneView`; no rendering regressions.
3. **Overhang + Face Normal colour modes** (§2 + §3) — build on top of §1's `ViewerColorMode` enum; implement both in one pass.
4. **Layer preview parser** (§5.1) — pure Swift data work; no UI yet; can be tested by printing layer counts to console.
5. **Layer preview scene + UI** (§5.2 + §5.3) — wire parser output into `GCodeSceneView` and `ContentView` overlay.

---

## Open Questions / Risks

| Topic | Note |
|-------|------|
| Wireframe line visibility | SceneKit `.line` primitive renders as 1 px and may be hard to see on device. May need to use thin `SCNCylinder` tubes for each edge instead, at the cost of more geometry. |
| Overhang rotation mapping | The mesh node has `eulerAngles = (-π/2, 0, 0)`. The overhang threshold must be computed in STL space (before rotation), not SceneKit world space. Use `n.z` directly (n is already in STL space when computed in `buildGeometry`). |
| Layer preview performance | A 200-layer print with 50k moves/layer = 10M segments. Lazy node construction is necessary. Consider capping displayed moves per layer or using GPU instancing. |
| `parsedLayers` memory | `[GCodeLayer]` for a large print could exceed 100 MB. Parse lazily or stream layers instead of holding all in memory. |
| Shared bed/axes helpers | `makePrintBedNode` / `makeAxesNode` are `private` in `STLSceneView.swift`. Either make them `internal` or move them to a new `SceneKitHelpers.swift`. |

---

## PROGRESS.md Updates

When each item is complete, move it from the **Viewer** todo block to the **Completed** section with a date stamp and reference this plan: `Plan: Plans/viewer_features.md`.
