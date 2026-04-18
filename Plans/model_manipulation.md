# Model Manipulation — Implementation Plan

## Goal

Give users full control over model position, orientation, and size before slicing. Currently the model is displayed as-loaded with no way to move, rotate, or scale it from within the app.

Features are grouped into phases so they can be shipped incrementally. Phases 1–4 are pure Swift/SceneKit with no bridge changes. Phase 5 (interactive gizmo) is the largest SwiftUI/SceneKit task. Phases 6–8 require minor bridge additions or larger state refactors.

---

## Phase 1 — Transform State & Numeric Panel (foundational)

All later phases build on this. Do it first.

### Approach

Add a `ModelTransform` value type to hold the current transform state and apply it as an `SCNMatrix4` on the model node. Show a numeric panel for direct input.

### Changes

**New: `ModelTransform.swift`**

```swift
struct ModelTransform {
    var position: SIMD3<Float> = .zero        // mm offset from bed centre
    var rotation: SIMD3<Float> = .zero        // Euler angles in degrees (X, Y, Z)
    var scale:    SIMD3<Float> = .one         // per-axis scale multiplier

    var scnMatrix: SCNMatrix4 {
        // compose: scale → rotate (ZYX) → translate
    }
}
```

**`STLSceneView.swift`**

Add `var transform: ModelTransform` property. In `updateUIView`, apply `transform.scnMatrix` to the mesh node instead of baking rotation into the geometry. Keep the existing −90° X rotation (STL Z-up → SceneKit Y-up) as a base; compose the user transform on top.

**`ContentView.swift`**

```swift
@State private var modelTransform = ModelTransform()
```

Pass into `STLSceneView`. Add a "Transform" button in the viewer overlay that shows a `TransformPanelView` sheet.

**New: `TransformPanelView.swift`**

A `Form` with three sections — Move, Rotate, Scale — each with X/Y/Z numeric text fields (mm or degrees or ×). Changes write back to `modelTransform` via a binding. Each section has a "Reset" button. A global "Reset All" at the bottom.

### File Summary

| File | Action |
|------|--------|
| `ModelTransform.swift` | **New** — value type + `scnMatrix` computed property |
| `STLSceneView.swift` | Edit — accept `transform:` prop, apply to mesh node |
| `TransformPanelView.swift` | **New** — Move / Rotate / Scale numeric form |
| `ContentView.swift` | Edit — `modelTransform` state + "Transform" overlay button |

---

## Phase 2 — Rotation

Builds on Phase 1's numeric panel and transform state.

### Approach

The Rotate section of `TransformPanelView` already exists after Phase 1. Add:

- **±90° quick buttons** next to each axis field for common rotations.
- **Snap-to-face ("Lay flat")** — identify the bottom-most face of the mesh (lowest average Z after current transform) and rotate the model so that face's normal points straight down (aligns with the bed).

### Snap-to-face Algorithm

```
1. For each triangle in the parsed STL, compute face normal (already available from STLParser).
2. Transform each normal by the current rotation to get world-space normals.
3. Candidate faces = faces whose world-space normal points mostly downward (n.y < -0.7 after mesh rotation).
4. Score = how flat the face is (|n.y| close to 1) and how large the face area is.
5. Pick the best candidate face.
6. Compute the rotation that maps that face's normal to (0, -1, 0).
7. Apply to modelTransform.rotation.
```

No bridge change needed — purely operates on the vertex data already parsed by `STLParser`.

### File Summary

| File | Action |
|------|--------|
| `TransformPanelView.swift` | Edit — ±90° quick buttons in Rotate section, "Lay Flat" button |
| `STLParser.swift` | Edit — expose face normals for snap-to-face computation |
| `ContentView.swift` | Edit — wire "Lay Flat" action |

---

## Phase 3 — Scale

### Approach

Extend the Scale section of `TransformPanelView`.

- **Lock proportions toggle** — when on, changing any one axis scales all three. Store a `lockScale: Bool` state.
- **Dimension fields** — show current bounding box size in mm alongside the % field. Editing the mm field back-calculates the scale factor.
- **Fit to bed** — compute the largest uniform scale such that the bounding box fits within `bedX × bedY × bedZ`. Requires the STL bounding box (already computed in `STLParser.buildGeometry`; expose it).

### File Summary

| File | Action |
|------|--------|
| `TransformPanelView.swift` | Edit — proportion lock, mm dimension fields, "Fit to Bed" button |
| `STLParser.swift` | Edit — expose `boundingBox: (min: SIMD3<Float>, max: SIMD3<Float>)` |
| `ContentView.swift` | Edit — wire "Fit to Bed" action with bed size from active printer profile |

---

## Phase 4 — Move / Placement Helpers

Quick-action buttons; no new UI primitives needed.

- **Center on bed** — sets `modelTransform.position.x` and `.y` to zero (model centred over bed origin).
- **Drop to bed** — sets `modelTransform.position.y` so the lowest vertex in world space sits at Y=0 (SceneKit). Requires the bounding box minimum after applying the full transform.

Both are buttons in the Move section of `TransformPanelView`.

### File Summary

| File | Action |
|------|--------|
| `TransformPanelView.swift` | Edit — "Center on Bed" and "Drop to Bed" buttons in Move section |

---

## Phase 5 — Interactive 3D Gizmo

The most complex phase. Touch-drag axes/arcs in the 3D viewer to transform the model.

### Approach

SceneKit's built-in camera control (`allowsCameraControl = true`) intercepts all touches for orbiting. To support a gizmo we must disable camera control while the gizmo is active and handle touches manually.

Add a **mode toggle button** in the viewer overlay: "Orbit" (default) vs "Transform". When in Transform mode, `allowsCameraControl = false` and touch events are routed to the gizmo.

#### Translate Gizmo

Three arrow `SCNNode`s (SCNCylinder + SCNCone) aligned to X/Y/Z axes, parented to an "origin" node at the model centre. Hit-test the touch; if an arrow is hit, project subsequent touch deltas onto that axis in world space and update `modelTransform.position`.

#### Rotate Gizmo

Three arc `SCNNode`s (thin torus approximated by a segmented line ring) around the model bounding sphere. Hit the arc → dragging rotates around that axis.

#### Scale Gizmo

Corner handle nodes on the bounding box. Drag scales uniformly (one finger) or per-axis (two fingers).

#### Touch Routing

Override `touchesBegan/Moved/Ended` in a `UIViewRepresentable` coordinator. Use `SCNView.hitTest(_:options:)` to determine which gizmo node was touched.

### File Summary

| File | Action |
|------|--------|
| `STLSceneView.swift` | Edit — `isTransformMode: Bool` prop; build/show/hide gizmo nodes; custom touch handling in coordinator |
| `ContentView.swift` | Edit — orbit/transform toggle button in viewer overlay |

---

## Phase 6 — Auto-orient

### Approach

Enumerate candidate rotations, score by overhang area, apply the best.

```
1. Start from 6 axis-aligned orientations (each face of the bounding box pointing down).
2. Optionally refine with a coarser grid search (e.g. 10° steps around each axis — ~1300 candidates).
3. For each candidate rotation: apply to all face normals, compute overhang area (faces where n.y < -cos(45°) × face area).
4. Pick the rotation with minimum overhang area.
5. Write to modelTransform.rotation.
```

Reuses the face normal + overhang computation already in `STLParser` (overhang colour mode). No bridge change needed.

Performance: 6 candidates is instant. 1300 candidates with ~50k triangles ≈ 65M dot products — run in a `Task.detached` with a progress indicator.

### File Summary

| File | Action |
|------|--------|
| `TransformPanelView.swift` | Edit — "Auto-Orient" button with async progress |
| `STLParser.swift` | Edit — expose face normals + areas for scoring |

---

## Phase 7 — Cut Tool

First phase requiring a new C bridge function.

### Bridge Change

```c
// slicer_bridge.h
int slicer_cut_at_z(SlicerHandle h,
                    float z_mm,
                    const char* output_lower_path,
                    const char* output_upper_path);
```

Implementation uses `Slic3r::Model::cut()` (available in PrusaSlicer's model API). Returns 0 on success; writes two STL files to the given paths.

### UI

- **Cut button** in the viewer overlay (scissors icon). Shows a `CutToolView` sheet.
- **Z-height slider** — range 0…model height in mm; live preview in the viewer.
- **Cut plane preview** — a semi-transparent `SCNPlane` node at the chosen Z height, updated as the slider moves.
- **"Cut" confirm button** — calls `slicer_cut_at_z`; presents an action sheet offering to load the lower or upper half (or both as separate files to export).

### File Summary

| File | Action |
|------|--------|
| `slicer_bridge.h/.cpp` | Edit — add `slicer_cut_at_z` |
| `CutToolView.swift` | **New** — Z slider + cut plane preview + confirm |
| `STLSceneView.swift` | Edit — accept optional `cutPlaneZ: Float?`, render semi-transparent cut plane |
| `ContentView.swift` | Edit — cut button + sheet presentation |

---

## Phase 8 — Multi-model

Largest state refactor.

### Approach

Replace the single `loadedSTLURL: URL?` with an array of `ModelInstance`.

```swift
struct ModelInstance: Identifiable {
    let id: UUID
    var url: URL
    var name: String
    var transform: ModelTransform
    var geometry: SCNGeometry?   // cached; nil = needs parse
}
```

`STLSceneView` renders one `SCNNode` per instance. Tapping a node in the viewer selects it; the transform panel operates on the selected instance.

#### Sub-tasks

- **Multi-model state** — replace single URL with `[ModelInstance]`; `STLSceneView` renders all nodes.
- **Add model** — second file-picker trigger appends to the list.
- **Per-model selection** — tap to select (highlight with emissive outline or bounding box gizmo); transform panel bound to selected instance.
- **Remove model** — delete button when model is selected, or swipe-to-delete in a model list sidebar.
- **Auto-arrange** — "Arrange All" button: either call `slicer_arrange_models` (wraps `Slic3r::arrangement::arrange`) or fall back to a simple row/grid layout for v1.

### File Summary

| File | Action |
|------|--------|
| `ModelInstance.swift` | **New** — instance value type |
| `STLSceneView.swift` | Edit — render array of instances; selection highlight |
| `ContentView.swift` | Edit — replace single model state with `[ModelInstance]`; add/remove; selected index |
| `slicer_bridge.h/.cpp` | Edit (optional) — `slicer_arrange_models` if going beyond grid layout |

---

## Implementation Order

| Phase | Effort | Bridge change? | Depends on |
|-------|--------|---------------|------------|
| 1 — Transform state + numeric panel | Medium | No | — |
| 2 — Rotation (snap-to-face) | Small | No | Phase 1 |
| 3 — Scale (lock + fit-to-bed) | Small | No | Phase 1 |
| 4 — Move helpers (center, drop-to-bed) | Trivial | No | Phase 1 |
| 5 — Interactive 3D gizmo | Large | No | Phases 1–4 |
| 6 — Auto-orient | Medium | No | Phase 2 |
| 7 — Cut tool | Medium | Yes | Phase 1 |
| 8 — Multi-model | Large | Optional | Phases 1–4 |

---

## Open Questions / Risks

| Topic | Note |
|-------|------|
| SCNMatrix4 composition order | Must apply transforms as: base STL rotation (−90° X) → user scale → user rotation → user translation. Wrong order produces shear/incorrect placement. |
| Gizmo vs orbit mode conflict | `SCNView.allowsCameraControl` cannot be per-touch; must toggle globally when entering transform mode. This is a UX trade-off. |
| Cut tool API | `Slic3r::Model::cut()` API may differ across PrusaSlicer versions. Check the actual commit in `~/ios-sources/PrusaSlicer/` before implementing. |
| Auto-orient search space | 6 candidates = instant; 1300 = ~1s on A-series chip. Profile before adding the fine search. |
| Multi-model bridge | `slicer_arrange_models` requires passing an array of STL paths + bed dimensions to the C bridge. Consider a simpler pure-Swift grid layout for v1 to avoid bridge complexity. |
| Transform → slicer handoff | The C bridge currently loads STL from file. With user transforms applied, the bridge must either (a) accept a transform matrix to apply at load time, or (b) the Swift side must bake the transform into a new STL file before slicing. Option (b) is simpler for v1. |

---

## PROGRESS.md Updates

When each phase is complete, move its items from the **Model Manipulation** todo block to the **Completed** section with a date stamp and reference this plan: `Plan: Plans/model_manipulation.md`.
