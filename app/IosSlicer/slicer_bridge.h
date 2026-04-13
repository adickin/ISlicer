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

#ifdef __cplusplus
}
#endif
