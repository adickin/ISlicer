// slicer_bridge.h
// Thin C wrapper around libslic3r's C++ API.
// Swift sees this via the ObjC bridging header — it cannot call C++ directly.

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// Opaque handle to a slicer context (holds Model + Print + Config)
typedef void* SlicerHandle;

// Lifecycle
SlicerHandle slicer_create(void);
void         slicer_destroy(SlicerHandle handle);

// Load an STL file from an absolute path on the filesystem.
// Returns 0 on success, negative on error.
int slicer_load_stl(SlicerHandle handle, const char* path);

// Slice with given layer height (mm) and infill percentage (0–100).
// Blocks until slicing is complete.
// Returns 0 on success, negative on error.
int slicer_slice(SlicerHandle handle, float layer_height, int infill_percent);

// Slice with a progress callback.
// progress_cb receives a value in [0.0, 1.0] and a user-supplied ctx pointer.
// Returns 0 on success, negative on error.
int slicer_slice_with_progress(SlicerHandle handle,
                               float layer_height,
                               int   infill_percent,
                               void (*progress_cb)(float progress, void* ctx),
                               void* ctx);

// Export G-code to the given absolute output path.
// Slice must have been called successfully first.
// Returns 0 on success, negative on error.
int slicer_export_gcode(SlicerHandle handle, const char* output_path);

// Cancel an in-progress slice. Safe to call from any thread while
// slicer_slice / slicer_slice_with_progress is running.
// The canceled flag is cleared automatically at the start of the next slice.
void slicer_cancel(SlicerHandle handle);

// Returns a human-readable error string for the last failed call.
// Valid until the next call on the same handle.
const char* slicer_last_error(SlicerHandle handle);

// ── Printer profile ───────────────────────────────────────────────────────────

// Printer configuration passed from Swift into the slicer context.
// gcode_flavor int values must match flavor_map[] in slicer_bridge.cpp.
typedef struct {
    // Bed
    float bed_x;                // mm (width)
    float bed_y;                // mm (depth)
    float bed_z;                // mm (max height)
    int   origin_at_center;     // 1 = bed origin is at centre, 0 = front-left
    int   heated_bed;           // 1 = true (informational; affects default temps)
    int   gcode_flavor;         // 0=Marlin,1=Marlin2,2=Klipper,3=RepRapSprinter,
                                // 4=RepRapFirmware,5=Teacup,6=MakerWare,7=Sailfish,
                                // 8=Mach3,9=MachineKit,10=Smoothie,11=NoExtrusion
    const char* start_gcode;    // null-terminated; may be NULL (keeps existing value)
    const char* end_gcode;      // null-terminated; may be NULL (keeps existing value)

    // Printhead extents (all in mm, relative to nozzle)
    float printhead_x_min;      // negative = toward left
    float printhead_y_min;      // negative = toward back
    float printhead_x_max;
    float printhead_y_max;
    float gantry_height;        // mm; used as extruder_clearance_height
    int   extruder_count;
    int   apply_extruder_offsets; // 1 = true

    // Extruder 0 shortcut (multi-extruder deferred)
    float nozzle_diameter;      // mm, e.g. 0.4
    float filament_diameter;    // mm, e.g. 1.75
} SlicerPrinterConfig;

// Apply a printer profile to the slicer context.
// Must be called before slicer_slice / slicer_slice_with_progress.
// Returns 0 on success, negative on error.
int slicer_apply_printer_config(SlicerHandle handle,
                                const SlicerPrinterConfig* cfg);

#ifdef __cplusplus
}
#endif
