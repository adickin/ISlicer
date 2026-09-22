# Additional Printer Profiles — Import Reference

A catalog of what's available in PrusaSlicer's bundled vendor profile library
(`~/ios-sources/PrusaSlicer/resources/profiles/*.ini`) beyond what's already
in the app, for picking the next batch to import. See [[printer_profiles.md]]
for the original data model / editor implementation plan and `BuiltInProfiles.swift`
for the current built-ins.

## Already imported

| Profile | Status | Source |
|---|---|---|
| Ender 3 S1 | **Verified** (real hardware, [[../PROGRESS.md]]) | Hand-authored, predates this catalog |
| Prusa i3 MK3S+ | Untested | `PrusaResearch.ini` |
| Prusa MINI+ | Untested | `PrusaResearch.ini` |
| Creality Ender-3 V2 | Untested | `Creality.ini` |
| Creality CR-10 | Untested | `Creality.ini` |
| Anycubic i3 Mega | Untested | `Anycubic.ini` |
| Artillery Sidewinder X1 | Untested | `Artillery.ini` |

All six imported profiles seed with `verified = false` (`PrinterProfile.verified`)
and appear in the picker's "Untested" section — see `ProfilePickerView.swift`.

## Everything else in the bundled library

Counts below are distinct physical printers (nozzle-size / MMU / duplication-mode
variants of the same machine collapsed into one row — pick the 0.4mm nozzle
variant unless a user asks for something else). SLA resin vendors
(`AnycubicSLA.ini`, `PrusaResearchSLA.ini`) are omitted — not applicable, this
app is FFF-only.

### Prusa Research (`PrusaResearch.ini`) — 14 more
MK2S, MK2.5, MK2.5S, MK3, MK4, MK4S, MK3.9, MK3.9S, MK3.5 & MK3.5S, CORE One,
CORE One L, XL, XL - 2T, XL - 5T

### Creality (`Creality.ini`) — 40 more
Ender-3, Ender-3 Pro, Ender-3 Neo, Ender-3 V2 Neo, Ender-3 S1, Ender-3 S1 Pro,
Ender-3 S1 Plus, Ender-3 Max, Ender-3 Max Neo, Ender-4, Ender-5, Ender-5 Pro,
Ender-5 Plus, Ender-5 S1, Ender-6, Ender-7, Ender-2, Ender-2 Pro, CR-5 Pro,
CR-5 Pro H, CR-6 SE, CR-6 Max, CR-10 SMART, CR-10 SMART Pro, CR-10 Mini,
CR-10 Max, CR-10 V2, CR-10 V3, CR-10 S, CR-10 S Pro, CR-10 S Pro V2, CR-10 S4,
CR-10 S5, CR-20, CR-20 Pro, CR-200B, CR-8, Sermoon-D1, Sermoon-V1, Sermoon-V1 Pro

> Note: `Creality.ini`'s own "Ender-3 S1" profile is a generic vendor
> template — our hand-authored `ender3S1` (verified on real hardware, with
> real head/gantry clearances) should stay the one used for that printer.
> Don't replace it with the vendor import.

### Voron (`Voron.ini`) — 12 distinct frames (36 raw entries incl. nozzle/volcano variants)
v0, v1 250/300/350 (Afterburner), v2 250/300/350 (standard + Afterburner),
Switchwire (+ Afterburner). Each size has 0.4mm and several "volcano"
high-flow nozzle variants — pick 0.4mm standard per size if imported.
These are DIY kits; frame size is a build choice, not a fixed spec, so
confirm which size(s) are worth adding before pulling from here.

### Geeetech (`Geeetech.ini`) — 25 models
M1, Thunder, ThunderPro, Mizar/MizarS/MizarPro/MizarMax/MizarM, A10Pro/M/T,
A20/M/T, A30Pro/M/T, E180, MeDucer, MeCreator, MeCreator2, GiantArmD200,
I3ProB/W/C

### Snapmaker (`Snapmaker.ini`) — 5 distinct machines (72 raw entries, mostly nozzle-size × kit-configuration combinations)
J1, A250, A350, A250 Dual, A350 Dual, Artisan — each sold with several
add-on kit configurations (QuickSwap, enclosure, etc.) that PrusaSlicer
models as separate profiles.

### Sovol (`Sovol.ini`) — 10 more
SV01, SV01 PRO, SV02, SV03, SV04 (+ Copy/Dual/Mirror/Single modes), SV05,
SV06, SV06 PLUS

### RatRig (`RatRig.ini`) — 13 distinct configs (39 raw entries × 3 nozzle sizes)
V-Core-4.0 in CoreXY/HYBRID/IDEX kinematics × 300/400/500mm, V-Core-3.1 ×
300/400/500mm, V-Minion-180. DIY kit — bed size is a build choice.

### MakerGear (`MakerGear.ini`) — 8 distinct machines (37 raw entries incl. nozzle size + duplication mode)
Micro, M2, M2 Dual, M3 Single Extruder, M3 Independent Dual Rev.0/Rev.1
(+ Duplication Mode variants), Ultra One

### QIDI Technology (`QIDITechnology.ini`) — 6 models
X-Plus 4 (+ BOX), Q1 Pro, X-MAX 3, X-Plus 3, X-smart 3

### Elegoo (`Elegoo.ini`) — 9 models
Neptune-1, Neptune-2, Neptune-2D, Neptune-2S, Neptune-X, Neptune-3,
Neptune-3 Max, Neptune-3 Plus, Neptune-3 Pro

### Artillery (`Artillery.ini`) — 7 more
Genius, Hornet, Sidewinder X3 Plus, Sidewinder X3 Pro, Sidewinder X4 Plus,
Sidewinder X4 Pro, Sidewinder X4 Max

### Anycubic (`Anycubic.ini`) — 5 more
Kossel Linear Plus, Kossel Pulley (Linear), Mega Zero, Predator, 4Max Pro 2.0

### LNL3D (`LNL3D.ini`) — 5 models
D3, D3 Vulcan, D3 V2, D5, D6

### TriLAB (`TriLAB.ini`) — 6 distinct (14 raw entries incl. FlexPrint variants)
DeltiQ L/M/XL, DeltiQ 2 (+ Plus, + FlexPrint), AzteQ Industrial, AzteQ Dynamic

### gCreate (`gCreate.ini`) — 4 distinct (17 raw entries × nozzle size)
gMax 1.5XT Plus, gMax 2, gMax 2 Pro, gMax 2 Dual (2in1 / Chimera)

### Zonestar (`Zonestar.ini`) — 11 models
Z5+M2, Z6, Z5X, Z8 (+M3/M4/E4/DDE hotend variants), Z9 (+M3/M4/E4/DDE hotend variants)

### HartSmartProducts (`HartSmartProducts.ini`) — 1 distinct (12 raw entries: 4 nozzle sizes × 3 modes)
HSP1-I (Takoto / Duplicator / Mirror modes)

### BIBO (`BIBO.ini`) — 2 distinct (10 raw entries: dual/single/ditto-mode combinations)
BIBO2 Touch, BIBO M2 BLTouch

### Rigid3D (`Rigid3D.ini`) — 4 models
Zero2, Zero3, Mucit, Mucit2

### Ultimaker (`Ultimaker.ini`) — 4 models
Ultimaker 2 (+ DXUv2), S3, S5/S7

### Small/niche vendors — 1-3 models each
- `Anker.ini` — AnkerMake M5, M5C
- `BIQU.ini` — BIQU BX
- `CocoaPress.ini` — Cocoa Press 0.8mm / 1.6mm (chocolate printer, not applicable here)
- `E2D.ini` — E2D i310, i311
- `FLSun.ini` — QQS Pro, Q5 (delta)
- `INAT.ini` — Proton X Rail, X Rod, XE-750
- `Infinity3D.ini` — DEV-350, DEV-200
- `Jubilee.ini` — Jubilee, Jubilee Volcano
- `LulzBot.ini` — Mini Aero, Taz6 Aero
- `PapapiuLab.ini` — Papapiu N1S
- `Print4Taste.ini` — mycusini 2.0 (chocolate printer, not applicable here)
- `Trimaker.ini` — Nebula Cloud, Nebula, Cosmos II

## Suggested next batch (popular consumer FFF, broad brand coverage)

If picking a next round, these cover the most-asked-about mainstream printers
not yet in the app:

- Creality Ender-3 (original) and/or Ender-5
- Prusa MK4 (current flagship, successor to the MK3S+ we already have)
- Elegoo Neptune-3 Pro (popular budget printer, different bed-leveling story than Creality)
- Sovol SV06
- Voron v2 350 (0.4mm, standard — most common build size; note DIY-kit caveat above)
- Ultimaker S5/S7 (enterprise/education segment, different G-code flavor conventions worth having for variety)

## How to pull one in

1. Find the printer's `[printer:Name]` section in the vendor `.ini`. Many
   specs live on an `inherits`-chain parent (often `[printer:*common*]` or a
   named mixin like `*bowden*`, `*CR10*`) — follow `inherits =` until values
   are found. `grep -n "^\[printer:"` lists section headers; `sed -n` reads
   ranges.
2. Fields needed, and where they map in `PrinterProfile.swift` /
   `ExtruderProfile.swift`:
   | ini key | Swift field |
   |---|---|
   | `bed_shape` (polygon, e.g. `0x0,250x0,250x210,0x210`) | `bedX`/`bedY` — width/depth = max X/Y of the polygon |
   | `max_print_height` | `bedZ` |
   | `gcode_flavor` | `gcodeFlavor` (must match a `GCodeFlavor` case) |
   | `start_gcode` / `end_gcode` | `startGCode` / `endGCode` — unescape `\n` → newline, `\"` → `"`; keep `{}`/`[]` placeholders as-is, libslic3r's own placeholder parser handles both syntaxes |
   | `nozzle_diameter` | `extruders[0].nozzleDiameter` |
   | `extruder_clearance_radius` | `printheadXMin`/`YMin` = `-radius`, `printheadXMax`/`YMax` = `+radius` (the C bridge collapses these back to a single radius anyway — see `slicer_bridge.cpp`'s `slicer_apply_printer_config`) |
   | `extruder_clearance_height` | `gantryHeight` |
3. Add a new `static let` in `BuiltInProfiles.swift` following the pattern of
   the existing untested profiles — set `verified = false` and a unique
   `builtInKey` (convention: `<vendor-lowercase>-<model-slug>`, e.g.
   `"creality-ender5"`). Add it to the `untested` array.
4. `ProfileStore.mergeInMissingBuiltIns()` will pick it up automatically for
   existing installs on next launch — no seed-version bump needed as long as
   the `builtInKey` is new.
5. Build and confirm it appears under "Untested" in `ProfilePickerView`.
   Leave it there — only promote to "Verified" once someone's actually
   printed with it on real hardware.
