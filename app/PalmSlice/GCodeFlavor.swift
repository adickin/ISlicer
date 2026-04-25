import Foundation

enum GCodeFlavor: String, CaseIterable, Codable, Identifiable {
    case marlin           = "Marlin"
    case marlin2          = "Marlin 2"
    case klipper          = "Klipper"
    case repRap           = "RepRap (Sprinter)"
    case repRapFirmware   = "RepRap (Firmware)"
    case teacup           = "Teacup"
    case makerWare        = "MakerWare"
    case sailfish         = "Sailfish"
    case mach3            = "Mach3"
    case machineKit       = "MachineKit"
    case smoothie         = "Smoothie"
    case noGCode          = "No G-Code"

    var id: String { rawValue }

    // Integer passed to slicer_apply_printer_config — must stay in sync
    // with flavor_map[] in slicer_bridge.cpp.
    var bridgeInt: Int32 {
        switch self {
        case .marlin:         return 0
        case .marlin2:        return 1
        case .klipper:        return 2
        case .repRap:         return 3
        case .repRapFirmware: return 4
        case .teacup:         return 5
        case .makerWare:      return 6
        case .sailfish:       return 7
        case .mach3:          return 8
        case .machineKit:     return 9
        case .smoothie:       return 10
        case .noGCode:        return 11
        }
    }
}
