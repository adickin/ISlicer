// slicer_bridge.cpp
// C wrapper implementation over libslic3r.
//
// Targets: PrusaSlicer 2.7 / 2.8 libslic3r API.
// If the build fails due to missing symbols, check the PrusaSlicer version:
//   cd ~/ios-sources/PrusaSlicer && git log --oneline -5
// and adjust the include paths or method names accordingly.

#include "slicer_bridge.h"

#include <string>
#include <stdexcept>
#include <cstring>
#include <functional>

// ── libslic3r core ────────────────────────────────────────────────────────────
#include <libslic3r/libslic3r.h>
#include <libslic3r/Model.hpp>
#include <libslic3r/Print.hpp>
#include <libslic3r/PrintConfig.hpp>
#include <libslic3r/Format/STL.hpp>
// GCode export lives inside Print::export_gcode in recent PrusaSlicer builds.
// If your version has a separate GCode.hpp, add: #include <libslic3r/GCode.hpp>

// ── Context ───────────────────────────────────────────────────────────────────
struct SlicerContext {
    Slic3r::Model              model;
    Slic3r::Print              print;
    Slic3r::DynamicPrintConfig config;
    std::string                last_error;

    // Printer dimensions — updated by slicer_apply_printer_config,
    // used by slicer_load_stl to centre the model on the correct bed.
    double bed_x = 220.0;
    double bed_y = 220.0;
    bool   origin_at_center = false;

    SlicerContext() {
        // Start from factory defaults so we have a valid config baseline.
        // FullPrintConfig::defaults() returns the canonical defaults object.
        config.apply(Slic3r::FullPrintConfig::defaults());

        // Override a minimal set for a usable FFF print.
        // These match a generic 0.4mm nozzle, 1.75mm PLA printer.
        config.set_key_value("layer_height",
            new Slic3r::ConfigOptionFloat(0.2));
        config.set_key_value("first_layer_height",
            new Slic3r::ConfigOptionFloatOrPercent(0.25, false));
        config.set_key_value("perimeters",
            new Slic3r::ConfigOptionInt(3));
        config.set_key_value("fill_density",
            new Slic3r::ConfigOptionPercent(20));
        config.set_key_value("fill_pattern",
            new Slic3r::ConfigOptionEnum<Slic3r::InfillPattern>(Slic3r::ipGyroid));

        // Nozzle / filament — must be arrays (one entry per extruder)
        config.set_key_value("nozzle_diameter",
            new Slic3r::ConfigOptionFloats({0.4}));
        config.set_key_value("filament_diameter",
            new Slic3r::ConfigOptionFloats({1.75}));
        config.set_key_value("temperature",
            new Slic3r::ConfigOptionInts({210}));
        config.set_key_value("first_layer_temperature",
            new Slic3r::ConfigOptionInts({215}));
        config.set_key_value("bed_temperature",
            new Slic3r::ConfigOptionInts({60}));
        config.set_key_value("first_layer_bed_temperature",
            new Slic3r::ConfigOptionInts({65}));

        // Retraction
        config.set_key_value("retract_length",
            new Slic3r::ConfigOptionFloats({5.0}));
        config.set_key_value("retract_speed",
            new Slic3r::ConfigOptionFloats({45.0}));
        config.set_key_value("retract_restart_extra",
            new Slic3r::ConfigOptionFloats({0.0}));

        // Fan
        config.set_key_value("fan_always_on",
            new Slic3r::ConfigOptionBools({true}));
        config.set_key_value("min_fan_speed",
            new Slic3r::ConfigOptionInts({35}));
        config.set_key_value("max_fan_speed",
            new Slic3r::ConfigOptionInts({100}));

        // Bed size (220×220×250 mm — generic Ender-class)
        config.set_key_value("bed_size",
            new Slic3r::ConfigOptionPoint(Slic3r::Vec2d(220, 220)));
        config.set_key_value("print_center",
            new Slic3r::ConfigOptionPoint(Slic3r::Vec2d(110, 110)));
        config.set_key_value("max_print_height",
            new Slic3r::ConfigOptionFloat(250));

        // Speeds
        config.set_key_value("perimeter_speed",
            new Slic3r::ConfigOptionFloat(45));
        config.set_key_value("infill_speed",
            new Slic3r::ConfigOptionFloat(80));
        config.set_key_value("first_layer_speed",
            new Slic3r::ConfigOptionFloatOrPercent(25, false));
        config.set_key_value("travel_speed",
            new Slic3r::ConfigOptionFloat(130));

        // Extrusion multiplier
        config.set_key_value("extrusion_multiplier",
            new Slic3r::ConfigOptionFloats({1.0}));

        // Gcode flavour (RepRap / Marlin)
        config.set_key_value("gcode_flavor",
            new Slic3r::ConfigOptionEnum<Slic3r::GCodeFlavor>(Slic3r::gcfMarlinLegacy));

        // No support structures for v1
        config.set_key_value("support_material",
            new Slic3r::ConfigOptionBool(false));
    }
};

// ── Helpers ──────────────────────────────────────────────────────────────────
static SlicerContext* CTX(SlicerHandle h) {
    return static_cast<SlicerContext*>(h);
}

static int set_err(SlicerContext* ctx, const std::exception& e) {
    ctx->last_error = e.what();
    return -1;
}

static int set_err(SlicerContext* ctx, const char* msg) {
    ctx->last_error = msg;
    return -1;
}

// ── GCodeFlavor mapping ───────────────────────────────────────────────────────
// Must stay in sync with GCodeFlavor.bridgeInt in GCodeFlavor.swift.
static const Slic3r::GCodeFlavor kFlavorMap[] = {
    Slic3r::gcfMarlinLegacy,    // 0  = .marlin
    Slic3r::gcfMarlinFirmware,  // 1  = .marlin2
    Slic3r::gcfKlipper,         // 2  = .klipper
    Slic3r::gcfRepRapSprinter,  // 3  = .repRap
    Slic3r::gcfRepRapFirmware,  // 4  = .repRapFirmware
    Slic3r::gcfTeacup,          // 5  = .teacup
    Slic3r::gcfMakerWare,       // 6  = .makerWare
    Slic3r::gcfSailfish,        // 7  = .sailfish
    Slic3r::gcfMach3,           // 8  = .mach3
    Slic3r::gcfMachinekit,      // 9  = .machineKit
    Slic3r::gcfSmoothie,        // 10 = .smoothie
    Slic3r::gcfNoExtrusion,     // 11 = .noGCode
};
static constexpr int kFlavorMapSize = static_cast<int>(sizeof(kFlavorMap) / sizeof(kFlavorMap[0]));

// ── Public C API ─────────────────────────────────────────────────────────────
extern "C" {

SlicerHandle slicer_create(void) {
    try {
        return new SlicerContext();
    } catch (const std::exception& e) {
        return nullptr;
    }
}

void slicer_destroy(SlicerHandle handle) {
    delete CTX(handle);
}

int slicer_load_stl(SlicerHandle handle, const char* path) {
    auto ctx = CTX(handle);
    try {
        ctx->model = Slic3r::Model();
        // load_stl fills the model in place; returns true on success
        bool ok = Slic3r::load_stl(path, &ctx->model, /*object_name=*/nullptr);
        if (!ok) return set_err(ctx, "load_stl returned false");

        // Add default instances so the model has geometry to slice
        ctx->model.add_default_instances();

        // Centre on the print bed using stored printer dimensions.
        double cx = ctx->origin_at_center ? 0.0 : ctx->bed_x / 2.0;
        double cy = ctx->origin_at_center ? 0.0 : ctx->bed_y / 2.0;
        Slic3r::Vec2d bed_centre(cx, cy);
        for (auto* obj : ctx->model.objects) {
            obj->center_around_origin();
        }
        ctx->model.center_instances_around_point(bed_centre);

        return 0;
    } catch (const std::exception& e) {
        return set_err(ctx, e);
    }
}

int slicer_slice(SlicerHandle handle, float layer_height, int infill_percent) {
    return slicer_slice_with_progress(handle, layer_height, infill_percent,
                                      /*progress_cb=*/nullptr,
                                      /*user_ctx=*/nullptr);
}

int slicer_slice_with_progress(SlicerHandle handle,
                               float layer_height,
                               int   infill_percent,
                               void (*progress_cb)(float, void*),
                               void* user_ctx)
{
    auto ctx = CTX(handle);
    try {
        ctx->config.set_key_value("layer_height",
            new Slic3r::ConfigOptionFloat(static_cast<double>(layer_height)));
        ctx->config.set_key_value("fill_density",
            new Slic3r::ConfigOptionPercent(infill_percent));

        ctx->print.clear();
        ctx->print.restart();  // clear any previous cancel flag

        if (progress_cb) {
            ctx->print.set_status_callback([=](const Slic3r::PrintBase::SlicingStatus& s) {
                progress_cb(static_cast<float>(s.percent), user_ctx);
            });
        } else {
            ctx->print.set_status_silent();
        }

        Slic3r::DynamicPrintConfig cfg_copy = ctx->config;
        ctx->print.apply(ctx->model, std::move(cfg_copy));

        ctx->print.process();

        ctx->print.set_status_default();
        return 0;
    } catch (const Slic3r::CanceledException&) {
        ctx->print.set_status_default();
        ctx->last_error = "canceled";
        return -2;  // distinct from general errors (-1)
    } catch (const std::exception& e) {
        ctx->print.set_status_default();
        return set_err(ctx, e);
    }
}

void slicer_cancel(SlicerHandle handle) {
    CTX(handle)->print.cancel();
}

int slicer_export_gcode(SlicerHandle handle, const char* output_path) {
    auto ctx = CTX(handle);
    try {
        // export_gcode signature (PrusaSlicer 2.7+):
        //   void Print::export_gcode(const std::string& path_template,
        //                            GCodeProcessorResult* result,
        //                            ThumbnailsGeneratorCallback thumbnail_cb)
        ctx->print.export_gcode(std::string(output_path),
                                /*result=*/nullptr,
                                /*thumbnail_cb=*/nullptr);
        return 0;
    } catch (const std::exception& e) {
        return set_err(ctx, e);
    }
}

const char* slicer_last_error(SlicerHandle handle) {
    return CTX(handle)->last_error.c_str();
}

int slicer_apply_printer_config(SlicerHandle handle, const SlicerPrinterConfig* cfg) {
    auto ctx = CTX(handle);
    if (!cfg) return set_err(ctx, "null printer config");
    try {
        // Store bed dimensions for use in slicer_load_stl.
        ctx->bed_x = static_cast<double>(cfg->bed_x);
        ctx->bed_y = static_cast<double>(cfg->bed_y);
        ctx->origin_at_center = (cfg->origin_at_center != 0);

        // bed_shape: rectangular polygon in mm.
        // When origin is at front-left, polygon starts at (0,0).
        // When origin is at centre, polygon starts at (-x/2, -y/2).
        double ox = ctx->origin_at_center ? -ctx->bed_x / 2.0 : 0.0;
        double oy = ctx->origin_at_center ? -ctx->bed_y / 2.0 : 0.0;
        Slic3r::ConfigOptionPoints bed_shape;
        bed_shape.values = {
            Slic3r::Vec2d(ox,              oy),
            Slic3r::Vec2d(ox + ctx->bed_x, oy),
            Slic3r::Vec2d(ox + ctx->bed_x, oy + ctx->bed_y),
            Slic3r::Vec2d(ox,              oy + ctx->bed_y),
        };
        ctx->config.set_key_value("bed_shape",
            new Slic3r::ConfigOptionPoints(bed_shape));

        // Max print height
        ctx->config.set_key_value("max_print_height",
            new Slic3r::ConfigOptionFloat(static_cast<double>(cfg->bed_z)));

        // G-Code flavor
        int fi = cfg->gcode_flavor;
        Slic3r::GCodeFlavor flavor = (fi >= 0 && fi < kFlavorMapSize)
            ? kFlavorMap[fi]
            : Slic3r::gcfMarlinLegacy;
        ctx->config.set_key_value("gcode_flavor",
            new Slic3r::ConfigOptionEnum<Slic3r::GCodeFlavor>(flavor));

        // Start / end gcode
        if (cfg->start_gcode) {
            ctx->config.set_key_value("start_gcode",
                new Slic3r::ConfigOptionString(std::string(cfg->start_gcode)));
        }
        if (cfg->end_gcode) {
            ctx->config.set_key_value("end_gcode",
                new Slic3r::ConfigOptionString(std::string(cfg->end_gcode)));
        }

        // Nozzle / filament diameters (per-extruder arrays)
        ctx->config.set_key_value("nozzle_diameter",
            new Slic3r::ConfigOptionFloats({static_cast<double>(cfg->nozzle_diameter)}));
        ctx->config.set_key_value("filament_diameter",
            new Slic3r::ConfigOptionFloats({static_cast<double>(cfg->filament_diameter)}));

        // Printhead clearance: use the largest half-extent as the radius.
        float radius = std::max({std::abs(cfg->printhead_x_min),
                                  std::abs(cfg->printhead_x_max),
                                  std::abs(cfg->printhead_y_min),
                                  std::abs(cfg->printhead_y_max)});
        ctx->config.set_key_value("extruder_clearance_radius",
            new Slic3r::ConfigOptionFloat(static_cast<double>(radius)));
        if (cfg->gantry_height > 0.0f) {
            ctx->config.set_key_value("extruder_clearance_height",
                new Slic3r::ConfigOptionFloat(static_cast<double>(cfg->gantry_height)));
        }

        return 0;
    } catch (const std::exception& e) {
        return set_err(ctx, e);
    }
}

} // extern "C"
