import simd
import SceneKit

struct ModelTransform: Equatable {
    var positionMM: SIMD3<Float> = .zero      // mm offset in SceneKit world space
    var rotationDeg: SIMD3<Float> = .zero     // Euler angles in degrees, SceneKit ZYX order
    var scale: SIMD3<Float> = SIMD3(1, 1, 1)

    static let identity = ModelTransform()

    var isIdentity: Bool { self == .identity }

    // MARK: - Drop to bed

    /// Minimum world-space Y (SceneKit units) produced by this transform, ignoring positionMM.
    /// The 8 AABB corners of the model (in pivot space: Y from 0 to height, centred in X/Z)
    /// are scaled and rotated, then the minimum Y is returned.
    func minWorldY(meshInfo: STLMeshInfo) -> Float {
        let hx: Float = meshInfo.sizeMMX / 200   // half-width in SceneKit units
        let hz: Float = meshInfo.sizeMMZ / 100   // full height
        let hy: Float = meshInfo.sizeMMY / 200   // half-depth

        let corners: [SIMD3<Float>] = [
            SIMD3(-hx, 0,  -hy), SIMD3(hx, 0,  -hy),
            SIMD3(-hx, hz, -hy), SIMD3(hx, hz, -hy),
            SIMD3(-hx, 0,   hy), SIMD3(hx, 0,   hy),
            SIMD3(-hx, hz,  hy), SIMD3(hx, hz,  hy),
        ]

        let s = scale
        // SceneKit applies Euler in Z→Y→X order
        let r = rotationDeg * (.pi / 180)
        let q = simd_quaternion(r.x, SIMD3<Float>(1,0,0))
              * simd_quaternion(r.y, SIMD3<Float>(0,1,0))
              * simd_quaternion(r.z, SIMD3<Float>(0,0,1))

        return corners.map { c in
            simd_act(q, SIMD3(c.x * s.x, c.y * s.y, c.z * s.z)).y
        }.min() ?? 0
    }

    /// Copy of this transform with positionMM.z adjusted so the model bottom sits exactly on the bed.
    /// positionMM.z is print Z (the vertical axis); maps to SceneKit Y via the pivot position.
    func droppedToBed(meshInfo: STLMeshInfo) -> ModelTransform {
        var t = self
        t.positionMM.z = -minWorldY(meshInfo: meshInfo) * 100
        return t
    }
}
