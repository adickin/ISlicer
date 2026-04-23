import simd

// Recomputes isIntersecting on every model in-place using world-space AABB pairs.
func checkIntersections(models: inout [PlacedModel]) {
    for i in models.indices { models[i].isIntersecting = false }

    let aabbs: [(min: SIMD3<Float>, max: SIMD3<Float>)?] = models.map(worldAABB(model:))

    for i in models.indices {
        guard let a = aabbs[i] else { continue }
        for j in (i + 1)..<models.count {
            guard let b = aabbs[j] else { continue }
            if aabbsOverlap(a, b) {
                models[i].isIntersecting = true
                models[j].isIntersecting = true
            }
        }
    }
}

// Computes the world-space AABB for a model in SceneKit units, matching the
// coordinate system used by STLSceneView (pivot transform + mesh –90° X rotation).
private func worldAABB(model: PlacedModel) -> (min: SIMD3<Float>, max: SIMD3<Float>)? {
    guard let info = model.meshInfo else { return nil }
    let t = model.transform

    // Local extents in SceneKit units (mirrors ModelTransform.minWorldY corners):
    //   X: ±sizeMMX/200   (width half-extent)
    //   Y:  0 … sizeMMZ/100  (height, bottom on bed)
    //   Z: ±sizeMMY/200   (depth half-extent)
    let hx: Float = info.sizeMMX / 200
    let hy: Float = info.sizeMMZ / 100
    let hz: Float = info.sizeMMY / 200

    let corners: [SIMD3<Float>] = [
        SIMD3(-hx, 0,  -hz), SIMD3(hx, 0,  -hz),
        SIMD3(-hx, hy, -hz), SIMD3(hx, hy, -hz),
        SIMD3(-hx, 0,   hz), SIMD3(hx, 0,   hz),
        SIMD3(-hx, hy,  hz), SIMD3(hx, hy,  hz),
    ]

    let s = t.scale
    let r = t.rotationDeg * (.pi / 180)
    // SceneKit applies Euler in Z→Y→X order (right-multiply = outermost first)
    let q = simd_quaternion(r.x, SIMD3<Float>(1, 0, 0))
          * simd_quaternion(r.y, SIMD3<Float>(0, 1, 0))
          * simd_quaternion(r.z, SIMD3<Float>(0, 0, 1))

    var minV = SIMD3<Float>(repeating: .infinity)
    var maxV = SIMD3<Float>(repeating: -.infinity)
    for c in corners {
        let p = simd_act(q, SIMD3(c.x * s.x, c.y * s.y, c.z * s.z))
        minV = simd_min(minV, p)
        maxV = simd_max(maxV, p)
    }

    let pos = t.positionMM / 100
    return (minV + pos, maxV + pos)
}

private func aabbsOverlap(
    _ a: (min: SIMD3<Float>, max: SIMD3<Float>),
    _ b: (min: SIMD3<Float>, max: SIMD3<Float>)
) -> Bool {
    a.min.x <= b.max.x && a.max.x >= b.min.x &&
    a.min.y <= b.max.y && a.max.y >= b.min.y &&
    a.min.z <= b.max.z && a.max.z >= b.min.z
}
