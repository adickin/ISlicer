import SceneKit
import simd

enum STLParseError: Error {
    case cannotReadFile
    case emptyMesh
    case malformedASCII
}

func parseSTL(url: URL) throws -> SCNGeometry {
    let data = try Data(contentsOf: url)
    guard data.count > 84 else { throw STLParseError.cannotReadFile }

    let triangles: [(v0: SIMD3<Float>, v1: SIMD3<Float>, v2: SIMD3<Float>)]

    if isASCII(data) {
        triangles = try parseASCII(data)
    } else {
        triangles = try parseBinary(data)
    }

    guard !triangles.isEmpty else { throw STLParseError.emptyMesh }

    return buildGeometry(triangles: triangles)
}

// MARK: - Format detection

private func isASCII(_ data: Data) -> Bool {
    // Binary STL: bytes 80-83 hold the triangle count N; if 84 + N*50 == data.count it's binary.
    // ASCII STL starts with "solid" followed by a space or newline.
    // We check the 5-byte prefix AND validate the binary size to disambiguate.
    let prefix = data.prefix(5)
    let startsWithSolid = prefix.elementsEqual("solid".utf8)
    if !startsWithSolid { return false }

    // Even if it starts with "solid", it might be a binary file with "solid" in the header.
    // Check if the binary triangle count is consistent with file size.
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
            // skip 12-byte normal — we recompute it
            offset += 12
            let v0 = loadVec3(ptr, at: offset);       offset += 12
            let v1 = loadVec3(ptr, at: offset);       offset += 12
            let v2 = loadVec3(ptr, at: offset);       offset += 12
            offset += 2  // attribute byte count
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
    triangles: [(v0: SIMD3<Float>, v1: SIMD3<Float>, v2: SIMD3<Float>)]
) -> SCNGeometry {
    let vertexCount = triangles.count * 3
    var positions = [SCNVector3]()
    var normals   = [SCNVector3]()
    positions.reserveCapacity(vertexCount)
    normals.reserveCapacity(vertexCount)

    // Compute AABB for normalization
    var minPt = SIMD3<Float>(repeating:  Float.infinity)
    var maxPt = SIMD3<Float>(repeating: -Float.infinity)

    for tri in triangles {
        for v in [tri.v0, tri.v1, tri.v2] {
            minPt = min(minPt, v)
            maxPt = max(maxPt, v)
        }
    }

    let center = (minPt + maxPt) * 0.5
    // STL coordinates are in mm. Scale to SceneKit units where 1 unit = 100 mm
    // so the model appears at its correct physical size on the bed grid.
    let scale: Float = 1.0 / 100.0

    for tri in triangles {
        // Normalize vertices
        let p0 = (tri.v0 - center) * scale
        let p1 = (tri.v1 - center) * scale
        let p2 = (tri.v2 - center) * scale

        // Recompute face normal from cross product
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
    }

    let vertexSource = SCNGeometrySource(vertices: positions)
    let normalSource = SCNGeometrySource(normals: normals)

    let indices = (0..<Int32(vertexCount)).map { $0 }
    let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)

    let geometry = SCNGeometry(sources: [vertexSource, normalSource], elements: [element])

    let mat = SCNMaterial()
    mat.diffuse.contents  = UIColor(white: 0.82, alpha: 1)
    mat.metalness.contents = Float(0.05)
    mat.roughness.contents = Float(0.65)
    mat.isDoubleSided      = true
    mat.lightingModel      = .physicallyBased
    geometry.materials = [mat]

    return geometry
}
