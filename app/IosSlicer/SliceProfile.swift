import Foundation

// Support structure style — maps to PrusaSlicer SupportMaterialStyle:
// smsGrid=0, smsSnug=1, smsTree=2, smsOrganic=3
enum SupportStyle: String, CaseIterable, Codable, Identifiable {
    case normal = "Normal (Snug)"
    case tree   = "Tree (Organic)"
    var id: String { rawValue }
    // Bridge uses smsSnug(1) for normal and smsOrganic(3) for tree
    var bridgeInt: Int32 { self == .normal ? 1 : 3 }
}

enum SupportPlacement: String, CaseIterable, Codable, Identifiable {
    case everywhere     = "Everywhere"
    case buildplateOnly = "Touching Build Plate Only"
    var id: String { rawValue }
}

// Sub-options when adhesion type is Brim.
// Maps to PrusaSlicer BrimType: btNoBrim=0, btOuterOnly=1, btInnerOnly=2, btOuterAndInner=3.
// btNoBrim is encoded by adhesionType == .none rather than here.
enum BrimType: String, CaseIterable, Codable, Identifiable {
    case outerOnly     = "Outer Only"
    case innerOnly     = "Inner Only"
    case outerAndInner = "Outer and Inner"
    var id: String { rawValue }
    var bridgeInt: Int32 {
        switch self {
        case .outerOnly:     return 1
        case .innerOnly:     return 2
        case .outerAndInner: return 3
        }
    }
}

// Top-level adhesion type. The bridge maps this to PrusaSlicer's separate
// brim_type / skirts / raft_layers keys.
enum AdhesionType: String, CaseIterable, Codable, Identifiable {
    case none  = "None"
    case skirt = "Skirt"
    case brim  = "Brim"
    case raft  = "Raft"
    var id: String { rawValue }
    var bridgeInt: Int32 {
        switch self {
        case .none:  return 0
        case .skirt: return 1
        case .brim:  return 2
        case .raft:  return 3
        }
    }
}

struct SliceProfile: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String = "My Profile"

    // MARK: - Layers
    var layerHeight: Double = 0.2        // mm  — PrusaSlicer: layer_height
    var firstLayerHeight: Double = 0.2   // mm  — PrusaSlicer: first_layer_height

    // MARK: - Walls
    var wallCount: Int = 3               // PrusaSlicer: perimeters
    var horizontalExpansion: Double = 0.0 // mm — PrusaSlicer: xy_size_compensation

    // MARK: - Top / Bottom
    var topLayers: Int = 4              // PrusaSlicer: top_solid_layers
    var bottomLayers: Int = 4           // PrusaSlicer: bottom_solid_layers
    // Min thickness overrides (0 = rely on layer count only)
    var topThickness: Double = 0.0      // mm — PrusaSlicer: top_solid_min_thickness
    var bottomThickness: Double = 0.0   // mm — PrusaSlicer: bottom_solid_min_thickness

    // MARK: - Infill
    var infillDensity: Int = 20         // %  — PrusaSlicer: fill_density
    var infillPattern: InfillPattern = .gyroid // PrusaSlicer: fill_pattern

    // MARK: - Speed (mm/s)
    var printSpeed: Double = 60.0       // PrusaSlicer: perimeter_speed
    var infillSpeed: Double = 80.0      // PrusaSlicer: infill_speed
    var travelSpeed: Double = 120.0     // PrusaSlicer: travel_speed
    var firstLayerSpeed: Double = 30.0  // PrusaSlicer: first_layer_speed

    // MARK: - Support
    var generateSupport: Bool = false
    var supportStyle: SupportStyle = .normal
    var supportPlacement: SupportPlacement = .everywhere
    var supportOverhangAngle: Int = 50   // degrees — PrusaSlicer: support_material_threshold
    var supportHorizontalExpansion: Double = 0.7 // mm — PrusaSlicer: support_material_xy_spacing
    var supportUseTowers: Bool = true    // PrusaSlicer: support_material_with_sheath

    // MARK: - Build Plate Adhesion
    var adhesionType: AdhesionType = .none
    // Brim sub-options (used when adhesionType == .brim)
    var brimType: BrimType = .outerOnly
    var brimWidth: Double = 8.0          // mm — PrusaSlicer: brim_width
    // Skirt sub-options (used when adhesionType == .skirt)
    var skirtLoops: Int = 1             // PrusaSlicer: skirts
    var skirtDistance: Double = 6.0     // mm — PrusaSlicer: skirt_distance
    // Raft sub-options (used when adhesionType == .raft)
    var raftLayers: Int = 3             // PrusaSlicer: raft_layers

    // MARK: - Summary (shown in picker row subtitle)
    var pickerSubtitle: String {
        let lh = String(format: "%.2g mm", layerHeight)
        let inf = "\(infillDensity)% \(infillPattern.rawValue)"
        let spd = "\(Int(printSpeed)) mm/s"
        let sup = generateSupport ? "Supports On" : "Supports Off"
        return "\(lh) · \(inf) · \(spd) · \(sup)"
    }
}
