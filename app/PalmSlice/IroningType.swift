import Foundation

// Maps to PrusaSlicer's IroningType enum in PrintConfig.hpp:
//   TopSurfaces=0, TopmostOnly=1, AllSolid=2
enum IroningType: String, CaseIterable, Codable, Identifiable {
    case topSurfaces = "All Top Surfaces"
    case topmostOnly = "Topmost Surface Only"
    case allSolid    = "All Solid Surfaces"

    var id: String { rawValue }

    var bridgeInt: Int32 {
        switch self {
        case .topSurfaces: return 0
        case .topmostOnly: return 1
        case .allSolid:    return 2
        }
    }
}
