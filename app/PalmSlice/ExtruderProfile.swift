import Foundation

struct ExtruderProfile: Codable, Identifiable {
    var id: UUID = UUID()
    var nozzleDiameter: Double = 0.4                      // mm
    var compatibleMaterialDiameters: [Double] = [1.75]    // mm; [1.75] or [2.85]
    var offsetX: Double = 0.0                             // mm
    var offsetY: Double = 0.0                             // mm
    var coolingFanNumber: Int = 0                         // 0-based fan index
    var extruderChangeDuration: Double = 0.0              // seconds
    var startGCode: String = ""
    var endGCode: String = ""
}
