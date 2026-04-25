import Foundation

struct MaterialProfile: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String = "My Material"

    // MARK: - Filament
    var filamentDiameter: Double = 1.75      // mm  — filament_diameter (per-extruder array)

    // MARK: - Temperatures
    var firstLayerTemp: Int = 215            // °C  — first_layer_temperature (per-extruder)
    var otherLayersTemp: Int = 210           // °C  — temperature (per-extruder)
    var firstLayerBedTemp: Int = 60          // °C  — first_layer_bed_temperature (per-extruder)
    var otherLayersBedTemp: Int = 55         // °C  — bed_temperature (per-extruder)

    // MARK: - Flow
    var extrusionMultiplier: Double = 1.0    // 0.5–2.0 — extrusion_multiplier (per-extruder)

    // MARK: - Retraction
    var retractionEnabled: Bool = true
    var retractionLength: Double = 5.0       // mm  — retract_length (per-extruder; 0 = no retract)
    var retractionSpeed: Double = 45.0       // mm/s — retract_speed (per-extruder)
    var retractionRestartExtra: Double = 0.0 // mm  — retract_restart_extra: extra pushed after deretraction to compensate ooze
    var zHop: Double = 0.0                   // mm  — retract_lift (per-extruder)
    var minTravelForRetraction: Double = 1.0 // mm  — retract_before_travel (per-extruder)

    // MARK: - Cooling / Fan
    var coolingEnabled: Bool = true          // bool — cooling (per-extruder)
    var minFanSpeed: Int = 35                // %   — min_fan_speed (per-extruder)
    var maxFanSpeed: Int = 100               // %   — max_fan_speed (per-extruder)
    var bridgeFanSpeed: Int = 100            // %   — bridge_fan_speed (per-extruder)
    var disableFanFirstLayers: Int = 3       // N   — disable_fan_first_layers (per-extruder)
    var fanBelowLayerTime: Int = 60          // sec — fan_below_layer_time: enable fan if layer prints in under N sec
    var slowdownBelowLayerTime: Int = 5      // sec — slowdown_below_layer_time: slow down if layer prints in under N sec
    var minPrintSpeed: Double = 10.0         // mm/s — min_print_speed: floor speed when cooling slowdown is active

    // MARK: - Summary (shown in picker row subtitle)
    var pickerSubtitle: String {
        let temp = "\(firstLayerTemp)/\(otherLayersTemp)°C"
        let retract = retractionEnabled ? "\(retractionLength) mm retract" : "No retract"
        let fan = coolingEnabled ? "Fan \(minFanSpeed)–\(maxFanSpeed)%" : "Fan off"
        return "\(temp) · \(retract) · \(fan)"
    }
}
