import SceneKit
import simd

// MARK: - ViewerColorMode

enum ViewerColorMode: CaseIterable, Equatable {
    case solid         // flat grey PBR — no vertex colours
    case overhang      // overhanging faces highlighted in orange-red
    case faceNormal    // RGB derived from face normal direction

    var displayName: String {
        switch self {
        case .solid:      return "Solid"
        case .overhang:   return "Overhang"
        case .faceNormal: return "Normals"
        }
    }

    var icon: String {
        switch self {
        case .solid:      return "cube"
        case .overhang:   return "exclamationmark.triangle"
        case .faceNormal: return "circle.hexagongrid.fill"
        }
    }

    var next: ViewerColorMode {
        let all = ViewerColorMode.allCases
        let idx = all.firstIndex(of: self)!
        return all[(idx + 1) % all.count]
    }
}

// MARK: - Error

enum STLParseError: Error {
    case cannotReadFile
    case emptyMesh
    case malformedASCII
}

// MARK: - Public entry point

func parseSTL(url: URL, colorMode: ViewerColorMode = .solid) throws -> SCNGeometry {
    let data = try Data(contentsOf: url)
    guard data.count > 84 else { throw STLParseError.cannotReadFile }

    let triangles: [(v0: SIMD3<Float>, v1: SIMD3<Float>, v2: SIMD3<Float>)]

    if isASCII(data) {
        triangles = try parseASCII(data)
    } else {
        triangles = try parseBinary(data)
    }

    guard !triangles.isEmpty else { throw STLParseError.emptyMesh }

    return buildGeometry(triangles: triangles, colorMode: colorMode)
}

// MARK: - Format detection

private func isASCII(_ data: Data) -> Bool {
    let prefix = data.prefix(5)
    let startsWithSolid = prefix.elementsEqual("solid".utf8)
    if !startsWithSolid { return false }

    let n = data[80..<84].withUnsafeBytes { $0.load(as: UInt32.self) }
    let expectedBinarySize = 84 + Int(n) * 50
    return expectedBinarySize != data.count
}

// MARK: - Binary parser

private func parseBinary(_ data: Data) throws -> [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] {
    let count = data[80..<84].withUnsafeBytes { $0.load(as: UInt32.self) }
    guard data.count >= 84 + Int(count) * 50 else { throw STLParseError.cannotReadFile }

    var result: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = []
    result.reserveCapacity(Int(count))

    data.withUnsafeBytes { ptr in
        var offset = 84
        for _ in 0..<count {
            offset += 12
            let v0 = loadVec3(ptr, at: offset);       offset += 12
            let v1 = loadVec3(ptr, at: offset);       offset += 12
            let v2 = loadVec3(ptr, at: offset);       offset += 12
            offset += 2
            result.append((v0, v1, v2))
        }
    }
    return result
}

private func loadVec3(_ ptr: UnsafeRawBufferPointer, at offset: Int) -> SIMD3<Float> {
    let x = ptr.loadUnaligned(fromByteOffset: offset,     as: Float.self)
    let y = ptr.loadUnaligned(fromByteOffset: offset + 4, as: Float.self)
    let z = ptr.loadUnaligned(fromByteOffset: offset + 8, as: Float.self)
    return SIMD3(x, y, z)
}

// MARK: - ASCII parser

private func parseASCII(_ data: Data) throws -> [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] {
    guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
        throw STLParseError.malformedASCII
    }

    var result: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = []
    var verts: [SIMD3<Float>] = []
    verts.reserveCapacity(3)

    for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("vertex") {
            let parts = trimmed.split(separator: " ")
            guard parts.count >= 4,
                  let x = Float(parts[1]),
                  let y = Float(parts[2]),
                  let z = Float(parts[3]) else { continue }
            verts.append(SIMD3(x, y, z))
            if verts.count == 3 {
                result.append((verts[0], verts[1], verts[2]))
                verts.removeAll(keepingCapacity: true)
            }
        }
    }
    return result
}

// MARK: - SCNGeometry builder

private func buildGeometry(
    triangles: [(v0: SIMD3<Float>, v1: SIMD3<Float>, v2: SIMD3<Float>)],
    colorMode: ViewerColorMode
) -> SCNGeometry {
    let vertexCount = triangles.count * 3
    var positions = [SCNVector3]()
    var normals   = [SCNVector3]()
    var colors    = [SIMD4<Float>]()
    positions.reserveCapacity(vertexCount)
    normals.reserveCapacity(vertexCount)
    if colorMode != .solid { colors.reserveCapacity(vertexCount) }

    // Compute AABB
    var minPt = SIMD3<Float>(repeating:  Float.infinity)
    var maxPt = SIMD3<Float>(repeating: -Float.infinity)
    for tri in triangles {
        for v in [tri.v0, tri.v1, tri.v2] { minPt = min(minPt, v); maxPt = max(maxPt, v) }
    }
    let center = (minPt + maxPt) * 0.5
    let scale: Float = 1.0 / 100.0

    for tri in triangles {
        let p0 = (tri.v0 - center) * scale
        let p1 = (tri.v1 - center) * scale
        let p2 = (tri.v2 - center) * scale

        let edge1 = p1 - p0
        let edge2 = p2 - p0
        var n = simd_cross(edge1, edge2)
        let len = simd_length(n)
        if len > 1e-10 { n /= len }

        let sn = SCNVector3(n.x, n.y, n.z)
        positions.append(SCNVector3(p0.x, p0.y, p0.z))
        positions.append(SCNVector3(p1.x, p1.y, p1.z))
        positions.append(SCNVector3(p2.x, p2.y, p2.z))
        normals.append(sn); normals.append(sn); normals.append(sn)

        if colorMode != .solid {
            // n is in STL space (Z=up). Overhang: face normal points downward.
            // n.z < -0.5 → face tilted > ~60° past horizontal → needs support.
            let c: SIMD4<Float>
            switch colorMode {
            case .solid:
                c = SIMD4(0.82, 0.82, 0.82, 1)
            case .overhang:
                if n.z < -0.5 {
                    c = SIMD4(1.0, 0.30, 0.05, 1.0)   // red-orange: definite overhang
                } else if n.z < 0.0 {
                    c = SIMD4(1.0, 0.82, 0.10, 1.0)   // yellow: borderline
                } else {
                    c = SIMD4(0.82, 0.82, 0.82, 1.0)  // grey: fine
                }
            case .faceNormal:
                c = SIMD4((n.x + 1) / 2, (n.y + 1) / 2, (n.z + 1) / 2, 1)
            }
            colors.append(c); colors.append(c); colors.append(c)
        }
    }

    // Vertex + normal sources
    var sources: [SCNGeometrySource] = [
        SCNGeometrySource(vertices: positions),
        SCNGeometrySource(normals: normals),
    ]

    // Optional per-vertex colour source
    if colorMode != .solid {
        let colorData = colors.withUnsafeBytes { Data($0) }
        let colorSource = SCNGeometrySource(
            data: colorData,
            semantic: .color,
            vectorCount: colors.count,
            usesFloatComponents: true,
            componentsPerVector: 4,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD4<Float>>.stride
        )
        sources.append(colorSource)
    }

    // Triangle element
    let triIndices = (0..<Int32(vertexCount)).map { $0 }
    let triElement = SCNGeometryElement(indices: triIndices, primitiveType: .triangles)

    // Wireframe lines element — always built; hidden via material transparency until toggled on.
    // Each triangle contributes 3 line segments: (3i→3i+1), (3i+1→3i+2), (3i+2→3i).
    var lineIndices = [Int32]()
    lineIndices.reserveCapacity(triangles.count * 6)
    for i in 0..<triangles.count {
        let b = Int32(i * 3)
        lineIndices.append(contentsOf: [b, b+1, b+1, b+2, b+2, b])
    }
    let lineElement = SCNGeometryElement(indices: lineIndices, primitiveType: .line)

    let geometry = SCNGeometry(sources: sources, elements: [triElement, lineElement])

    // Face material — PBR for solid, constant for colour modes (vertex colours drive output)
    let faceMat = SCNMaterial()
    switch colorMode {
    case .solid:
        faceMat.diffuse.contents   = UIColor(white: 0.82, alpha: 1)
        faceMat.metalness.contents = Float(0.05)
        faceMat.roughness.contents = Float(0.65)
        faceMat.isDoubleSided      = true
        faceMat.lightingModel      = .physicallyBased
    case .overhang, .faceNormal:
        faceMat.diffuse.contents  = UIColor.white   // vertex colours modulate white → pure vertex colour
        faceMat.isDoubleSided     = true
        faceMat.lightingModel     = .constant
    }

    // Wireframe material — dark, hidden initially (transparency = 0)
    // Vertex colours multiply with dark diffuse, so wireframe stays dark in all colour modes.
    let wireMat = SCNMaterial()
    wireMat.diffuse.contents = UIColor(white: 0.18, alpha: 1)
    wireMat.lightingModel    = .constant
    wireMat.transparency     = 0.0   // STLSceneView toggles this to 1.0 when wireframe is on

    geometry.materials = [faceMat, wireMat]
    return geometry
}
