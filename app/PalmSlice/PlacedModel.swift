import SceneKit
import Foundation

struct PlacedModel: Identifiable {
    let id: UUID
    var url: URL
    var name: String
    var geometry: SCNGeometry?
    var transform: ModelTransform
    var meshInfo: STLMeshInfo?
    var bvh: TriangleBVH?
    var isIntersecting: Bool = false
}
