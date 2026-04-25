import Foundation

struct PrinterProfile: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String = "My Printer"

    // MARK: Bed / Machine
    var bedX: Double = 220.0               // mm (width)
    var bedY: Double = 220.0               // mm (depth)
    var bedZ: Double = 250.0               // mm (height)
    var buildPlateShape: BuildPlateShape = .rectangular
    var originAtCenter: Bool = false
    var heatedBed: Bool = true
    var heatedBuildVolume: Bool = false

    // MARK: G-Code
    var gcodeFlavor: GCodeFlavor = .marlin
    var startGCode: String = ""
    var endGCode: String = ""

    // MARK: Printhead
    var printheadXMin: Double = -2.0       // mm (toward left)
    var printheadYMin: Double = -2.0       // mm (toward back)
    var printheadXMax: Double = 2.0        // mm (toward right)
    var printheadYMax: Double = 2.0        // mm (toward front)
    var gantryHeight: Double = 0.0         // mm
    var numberOfExtruders: Int = 1
    var applyExtruderOffsetsToGCode: Bool = false
    var startGCodeMustBeFirst: Bool = false

    // MARK: Per-extruder
    var extruders: [ExtruderProfile] = [ExtruderProfile()]
}
