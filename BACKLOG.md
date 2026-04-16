# IosSlicer — Backlog

Features and ideas that are out of scope for v1 but worth tracking.

---

## STL Unit Detection

**Problem:** The STL format has no unit metadata. A file exported in inches or metres will load at the wrong physical size on the bed grid (e.g. a 60 mm model exported in inches will appear as 1524 mm wide).

**Approach:** Heuristic detection based on bounding box size against expected printable ranges, followed by a user confirmation dialog:

| Max extent (raw units) | Likely unit | Suggested scale |
|------------------------|-------------|-----------------|
| < 1.0                  | Metres      | ×1000           |
| 1 – 500                | mm          | ×1 (no change)  |
| 500 – 25400            | Inches      | ×25.4           |
| > 25400                | Unknown     | Ask user        |

**UX:** If the detected unit is not mm, show an alert after import:
> "This model's largest dimension is X units. Did you export in inches or metres?"
> [Keep as mm] [Scale from inches] [Scale from metres]

**Caveats:**
- Ranges overlap — a 500 mm part and a 20" part are both plausible. Heuristic is a best guess, not a guarantee.
- Only trigger the dialog when the size is clearly outside the normal mm printing range (< 1 mm or > 500 mm largest axis) to avoid annoying users with correctly-sized models.
- The scale correction should update both the visual geometry and the STL passed to the slicer (or apply a scale transform in the bridge).

---
