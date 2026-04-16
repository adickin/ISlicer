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

    // Set to true once slicer_apply_slice_config has been called so that
    // slicer_slice_with_progress doesn't clobber the slice settings with its
    // legacy layer_height / infill_percent parameters.
    bool   slice_config_applied = false;

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
        // layer_height and infill_percent are kept in the signature for compatibility
        // but the values are now owned by slicer_apply_slice_config. If no slice
        // config has been applied (legacy call path), fall back to the parameters.
        if (!ctx->slice_config_applied) {
            ctx->config.set_key_value("layer_height",
                new Slic3r::ConfigOptionFloat(static_cast<double>(layer_height)));
            ctx->config.set_key_value("fill_density",
                new Slic3r::ConfigOptionPercent(infill_percent));
        }

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

int slicer_apply_slice_config(SlicerHandle handle, const SlicerSliceConfig* cfg) {
    auto ctx = CTX(handle);
    if (!cfg) return set_err(ctx, "null slice config");
    try {
        // Layers
        ctx->config.set_key_value("layer_height",
            new Slic3r::ConfigOptionFloat(static_cast<double>(cfg->layer_height)));
        ctx->config.set_key_value("first_layer_height",
            new Slic3r::ConfigOptionFloatOrPercent(
                static_cast<double>(cfg->first_layer_height), false));

        // Walls
        ctx->config.set_key_value("perimeters",
            new Slic3r::ConfigOptionInt(cfg->wall_count));
        ctx->config.set_key_value("xy_size_compensation",
            new Slic3r::ConfigOptionFloat(static_cast<double>(cfg->horizontal_expansion)));

        // Top / Bottom
        ctx->config.set_key_value("top_solid_layers",
            new Slic3r::ConfigOptionInt(cfg->top_layers));
        ctx->config.set_key_value("bottom_solid_layers",
            new Slic3r::ConfigOptionInt(cfg->bottom_layers));
        if (cfg->top_thickness > 0.0f) {
            ctx->config.set_key_value("top_solid_min_thickness",
                new Slic3r::ConfigOptionFloat(static_cast<double>(cfg->top_thickness)));
        }
        if (cfg->bottom_thickness > 0.0f) {
            ctx->config.set_key_value("bottom_solid_min_thickness",
                new Slic3r::ConfigOptionFloat(static_cast<double>(cfg->bottom_thickness)));
        }

        // Infill
        ctx->config.set_key_value("fill_density",
            new Slic3r::ConfigOptionPercent(cfg->infill_density));
        ctx->config.set_key_value("fill_pattern",
            new Slic3r::ConfigOptionEnum<Slic3r::InfillPattern>(
                static_cast<Slic3r::InfillPattern>(cfg->infill_pattern)));

        // Speed — types verified against PrintConfig.hpp:
        // perimeter_speed: ConfigOptionFloat
        // infill_speed:    ConfigOptionFloat
        // travel_speed:    ConfigOptionFloat
        // first_layer_speed: ConfigOptionFloatOrPercent
        ctx->config.set_key_value("perimeter_speed",
            new Slic3r::ConfigOptionFloat(static_cast<double>(cfg->print_speed)));
        ctx->config.set_key_value("infill_speed",
            new Slic3r::ConfigOptionFloat(static_cast<double>(cfg->infill_speed)));
        ctx->config.set_key_value("travel_speed",
            new Slic3r::ConfigOptionFloat(static_cast<double>(cfg->travel_speed)));
        ctx->config.set_key_value("first_layer_speed",
            new Slic3r::ConfigOptionFloatOrPercent(
                static_cast<double>(cfg->first_layer_speed), false));

        // Support
        bool gen_support = (cfg->generate_support != 0);
        ctx->config.set_key_value("support_material",
            new Slic3r::ConfigOptionBool(gen_support));
        if (gen_support) {
            // smsGrid=0, smsSnug=1, smsTree=2, smsOrganic=3
            Slic3r::SupportMaterialStyle sms = (cfg->support_style == 0)
                ? Slic3r::smsSnug : Slic3r::smsOrganic;
            ctx->config.set_key_value("support_material_style",
                new Slic3r::ConfigOptionEnum<Slic3r::SupportMaterialStyle>(sms));
            ctx->config.set_key_value("support_material_buildplate_only",
                new Slic3r::ConfigOptionBool(cfg->support_buildplate_only != 0));
            ctx->config.set_key_value("support_material_threshold",
                new Slic3r::ConfigOptionInt(cfg->support_overhang_angle));
            // xy_spacing is stored as absolute mm (percent=false)
            ctx->config.set_key_value("support_material_xy_spacing",
                new Slic3r::ConfigOptionFloatOrPercent(
                    static_cast<double>(cfg->support_xy_spacing), false));
            ctx->config.set_key_value("support_material_with_sheath",
                new Slic3r::ConfigOptionBool(cfg->support_use_towers != 0));
        }

        // Build plate adhesion
        // adhesion_type: 0=none, 1=skirt, 2=brim, 3=raft
        switch (cfg->adhesion_type) {
            case 0: // none
                ctx->config.set_key_value("brim_type",
                    new Slic3r::ConfigOptionEnum<Slic3r::BrimType>(Slic3r::btNoBrim));
                ctx->config.set_key_value("skirts",
                    new Slic3r::ConfigOptionInt(0));
                ctx->config.set_key_value("raft_layers",
                    new Slic3r::ConfigOptionInt(0));
                break;
            case 1: // skirt
                ctx->config.set_key_value("brim_type",
                    new Slic3r::ConfigOptionEnum<Slic3r::BrimType>(Slic3r::btNoBrim));
                ctx->config.set_key_value("skirts",
                    new Slic3r::ConfigOptionInt(cfg->skirt_loops));
                ctx->config.set_key_value("skirt_distance",
                    new Slic3r::ConfigOptionFloat(static_cast<double>(cfg->skirt_distance)));
                ctx->config.set_key_value("raft_layers",
                    new Slic3r::ConfigOptionInt(0));
                break;
            case 2: { // brim
                // brim_type: 1=outer_only, 2=inner_only, 3=outer_and_inner
                int bt = cfg->brim_type;
                Slic3r::BrimType brim = (bt == 2) ? Slic3r::btInnerOnly
                                      : (bt == 3) ? Slic3r::btOuterAndInner
                                                  : Slic3r::btOuterOnly;
                ctx->config.set_key_value("brim_type",
                    new Slic3r::ConfigOptionEnum<Slic3r::BrimType>(brim));
                ctx->config.set_key_value("brim_width",
                    new Slic3r::ConfigOptionFloat(static_cast<double>(cfg->brim_width)));
                ctx->config.set_key_value("skirts",
                    new Slic3r::ConfigOptionInt(0));
                ctx->config.set_key_value("raft_layers",
                    new Slic3r::ConfigOptionInt(0));
                break;
            }
            case 3: // raft
                ctx->config.set_key_value("brim_type",
                    new Slic3r::ConfigOptionEnum<Slic3r::BrimType>(Slic3r::btNoBrim));
                ctx->config.set_key_value("skirts",
                    new Slic3r::ConfigOptionInt(0));
                ctx->config.set_key_value("raft_layers",
                    new Slic3r::ConfigOptionInt(cfg->raft_layers));
                break;
            default:
                break;
        }

        ctx->slice_config_applied = true;
        return 0;
    } catch (const std::exception& e) {
        return set_err(ctx, e);
    }
}

int slicer_apply_material_config(SlicerHandle handle,
                                 const SlicerMaterialConfig* cfg) {
    auto ctx = CTX(handle);
    if (!cfg) return set_err(ctx, "null material config");
    try {
        // Filament diameter — overrides the value set by slicer_apply_printer_config
        ctx->config.set_key_value("filament_diameter",
            new Slic3r::ConfigOptionFloats({static_cast<double>(cfg->filament_diameter)}));

        // Temperatures
        ctx->config.set_key_value("first_layer_temperature",
            new Slic3r::ConfigOptionInts({cfg->first_layer_temperature}));
        ctx->config.set_key_value("temperature",
            new Slic3r::ConfigOptionInts({cfg->temperature}));
        ctx->config.set_key_value("first_layer_bed_temperature",
            new Slic3r::ConfigOptionInts({cfg->first_layer_bed_temperature}));
        ctx->config.set_key_value("bed_temperature",
            new Slic3r::ConfigOptionInts({cfg->bed_temperature}));

        // Flow
        ctx->config.set_key_value("extrusion_multiplier",
            new Slic3r::ConfigOptionFloats({static_cast<double>(cfg->extrusion_multiplier)}));

        // Retraction — retract_length == 0 disables retraction natively
        ctx->config.set_key_value("retract_length",
            new Slic3r::ConfigOptionFloats({static_cast<double>(cfg->retract_length)}));
        ctx->config.set_key_value("retract_speed",
            new Slic3r::ConfigOptionFloats({static_cast<double>(cfg->retract_speed)}));
        ctx->config.set_key_value("retract_restart_extra",
            new Slic3r::ConfigOptionFloats({static_cast<double>(cfg->retract_restart_extra)}));
        ctx->config.set_key_value("retract_lift",
            new Slic3r::ConfigOptionFloats({static_cast<double>(cfg->retract_lift)}));
        ctx->config.set_key_value("retract_before_travel",
            new Slic3r::ConfigOptionFloats({static_cast<double>(cfg->retract_before_travel)}));

        // Fan / cooling
        ctx->config.set_key_value("cooling",
            new Slic3r::ConfigOptionBools({cfg->cooling != 0}));
        ctx->config.set_key_value("min_fan_speed",
            new Slic3r::ConfigOptionInts({cfg->min_fan_speed}));
        ctx->config.set_key_value("max_fan_speed",
            new Slic3r::ConfigOptionInts({cfg->max_fan_speed}));
        ctx->config.set_key_value("bridge_fan_speed",
            new Slic3r::ConfigOptionInts({cfg->bridge_fan_speed}));
        ctx->config.set_key_value("disable_fan_first_layers",
            new Slic3r::ConfigOptionInts({cfg->disable_fan_first_layers}));
        ctx->config.set_key_value("fan_below_layer_time",
            new Slic3r::ConfigOptionInts({cfg->fan_below_layer_time}));
        ctx->config.set_key_value("slowdown_below_layer_time",
            new Slic3r::ConfigOptionInts({cfg->slowdown_below_layer_time}));
        ctx->config.set_key_value("min_print_speed",
            new Slic3r::ConfigOptionFloats({static_cast<double>(cfg->min_print_speed)}));

        return 0;
    } catch (const std::exception& e) {
        return set_err(ctx, e);
    }
}

} // extern "C"
