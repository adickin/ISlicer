# PalmSlice — Future Features

Planned features that are not yet implemented. This is the single place to
look for "what's next" — it consolidates the previous `BACKLOG.md` plus the
longer-term (non-checklist) items that were living in `PROGRESS.md`'s To Do
section. Where a detailed implementation plan already exists under `Plans/`,
this doc links to it instead of duplicating it.

When a feature here gets built, move it to `PROGRESS.md`'s Completed section
with a date stamp (per the existing convention) and delete its entry here.

---

## iPad UI

Split-view layout for iPad: a persistent settings/profile panel alongside the
3D viewer instead of the iPhone-style collapsible bottom sheet. No detailed
plan written yet — needs a design pass on how the existing bottom-panel
sections (printer/material/slice profile rows, transform panel, layer slider)
map onto a `NavigationSplitView` or custom two-pane layout, and how it
degrades on the iPad's compact-width multitasking sizes.

## Color Customization

A way for the user to set colors — most likely a filament/material color
swatch (shown in `MaterialProfilePickerView` and used to tint the model in
the viewer) and/or a UI accent color. Neither `MaterialProfile` nor
`SliceProfile` currently has a color field. Needs scoping: filament color
only, or also a viewer/app theme color?

## Printer Profiles

- **Additional built-in profiles** — the suggested first batch is in; see `Plans/additional_printer_profiles.md`
  for the remaining catalog and how-to-import steps.
- **Multi-extruder bridge** — `SlicerPrinterConfig` currently only passes
  extruder 0; extend to pass per-extruder arrays for nozzle/filament diameter
  and offsets.
- **Reset profile to default** — "Reset to built-in defaults" button in the
  printer profile editor for built-in profiles.

## Slicing Profiles

- **Additional speed settings** — outer perimeter speed, small perimeter
  speed, bridge speed, top solid infill speed (currently only the 4 main
  speeds are exposed; all others use PrusaSlicer defaults).
- **Reset profile to default** — "Reset to built-in defaults" button for
  built-in slice profiles (Draft / Standard / Fine).
- **Seam position** — aligned / nearest / random (`seam_position` key).
- **Extrusion width overrides** — per-feature extrusion width (perimeter,
  infill, top solid) for fine-tuning on non-standard nozzle sizes.

## Model Manipulation

Full plan: `Plans/model_manipulation.md`. Remaining phases:

- **Auto-orient** (Phase 6) — rotate to minimize support area; scores
  candidate rotations by overhang.
- **Cut tool** (Phase 7) — Z-height slider + live cut-plane preview;
  new `slicer_cut_at_z` C bridge call.
- **Multi-model** (Phase 8) — load/place/slice multiple STLs at once,
  with per-model transforms and intersection highlighting. Detailed
  step-by-step plan: `Plans/multi-model.md`.

## STL Import

- **STL Unit Detection** — the STL format has no unit metadata, so a model
  exported in inches or metres loads at the wrong physical size (e.g. a
  60&nbsp;mm model exported in inches appears as 1524&nbsp;mm wide).
  Approach: heuristic detection based on bounding-box size, followed by a
  user confirmation dialog.

  | Max extent (raw units) | Likely unit | Suggested scale |
  |------------------------|-------------|-----------------|
  | < 1.0                  | Metres      | ×1000           |
  | 1 – 500                | mm          | ×1 (no change)  |
  | 500 – 25400            | Inches      | ×25.4           |
  | > 25400                | Unknown     | Ask user        |

  If the detected unit is not mm, show an alert after import:
  > "This model's largest dimension is X units. Did you export in inches or
  > metres?" — [Keep as mm] [Scale from inches] [Scale from metres]

  Caveats: ranges overlap (a 500&nbsp;mm part and a 20" part are both
  plausible), so only trigger the dialog when the size is clearly outside
  the normal mm printing range (< 1&nbsp;mm or > 500&nbsp;mm largest axis).
  The scale correction should update both the visual geometry and the STL
  passed to the slicer (or apply a scale transform in the bridge).

- **Direct import from model hubs** — pass a Thingiverse (or other model
  hub) URL; the app downloads the zip and auto-slices its contents. Far-future,
  no design work started.

## Infrastructure

- **iPad layout** — see iPad UI above.
- **Haptic feedback** on slice complete.
- **iCloud Drive sync** for profiles and recent files.
- **Broader TestFlight distribution** — currently uploaded for internal
  testing (see `PROGRESS.md`); expanding to an external tester group is
  still open.
