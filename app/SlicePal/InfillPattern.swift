import Foundation

// Maps to PrusaSlicer's InfillPattern enum in PrintConfig.hpp.
// bridgeInt values must match the enum ordinals exactly — verified against
// the PrusaSlicer source at ~/ios-sources/PrusaSlicer/src/libslic3r/PrintConfig.hpp:
//   ipRectilinear=0, ipMonotonic=1, ipMonotonicLines=2, ipAlignedRectilinear=3,
//   ipGrid=4, ipTriangles=5, ipStars=6, ipCubic=7, ipLine=8, ipConcentric=9,
//   ipHoneycomb=10, ip3DHoneycomb=11, ipGyroid=12, ipHilbertCurve=13,
//   ipArchimedeanChords=14, ipOctagramSpiral=15, ipAdaptiveCubic=16,
//   ipSupportCubic=17, ipSupportBase=18, ipLightning=19
enum InfillPattern: String, CaseIterable, Codable, Identifiable {
    case gyroid        = "Gyroid"
    case grid          = "Grid"
    case honeycomb     = "Honeycomb"
    case rectilinear   = "Lines"
    case triangles     = "Triangles"
    case cubic         = "Cubic"
    case adaptiveCubic = "Adaptive Cubic"
    case lightning     = "Lightning"

    var id: String { rawValue }

    var bridgeInt: Int32 {
        switch self {
        case .rectilinear:   return 0
        case .grid:          return 4
        case .triangles:     return 5
        case .cubic:         return 7
        case .honeycomb:     return 10
        case .gyroid:        return 12
        case .adaptiveCubic: return 16
        case .lightning:     return 19
        }
    }
}
