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

## STL Import

- **STL unit detection (inches)** — the metres case is done (sub-2 mm
  imports offer a one-tap ×1000 fix, 2026-08-23). Still open: detecting
  inch-exported models. A 60 mm model exported in inches appears as
  1524 mm wide. Heuristic: if the largest axis is clearly outside the normal
  printing range (> 500 mm), offer [Keep as mm] / [Scale from inches ×25.4].
  Ranges overlap with legitimately large parts, so only prompt when the size
  is far outside the bed.

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

## Release / Testing

- **Verify untested printer profiles on real hardware** — 13 of 14 built-ins
  are unverified; promote each to Verified only after a real print.
- **Printer-model placeholders** — `printer_model` / `printer_settings_id`
  aren't set by the bridge, so vendor start G-code that references them
  renders empty (worked around for Prusa by hardcoding). Consider exposing
  them in `SlicerPrinterConfig`.
- **Ultimaker S5/S7 (dual extruder)** — deliberately not included yet. Needs
  the multi-extruder bridge plus its Griffin-header start G-code (importing
  extruder 0 only logs a non-fatal "invalid toolchange (T1)"). Re-import from
  `Ultimaker.ini` once multi-extruder is supported.
- **Refresh seeded built-ins on update** — `mergeInMissingBuiltIns` only adds
  new profiles; saved copies of existing built-ins (e.g. MK3S+/MINI+) keep
  stale G-code. A per-profile "reset to built-in" would fix this too.
