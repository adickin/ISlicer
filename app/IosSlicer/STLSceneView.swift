import SceneKit
import SwiftUI

struct STLSceneView: UIViewRepresentable {
    let geometry: SCNGeometry?
    /// Printer bed width in mm (X axis). Defaults to 220 mm if no printer selected.
    var bedX: Double = 220
    /// Printer bed depth in mm (Y axis). Defaults to 220 mm if no printer selected.
    var bedY: Double = 220

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = UIColor(white: 0.10, alpha: 1)
        scnView.antialiasingMode = .multisampling4X
        scnView.allowsCameraControl = true
        scnView.rendersContinuously = true

        let ctrl = scnView.defaultCameraController
        ctrl.interactionMode = .orbitTurntable
        ctrl.minimumVerticalAngle = -89
        ctrl.maximumVerticalAngle  =  89

        let scene = SCNScene()
        scnView.scene = scene

        // Print bed grid — sized to actual printer bed dimensions
        let bedNode = makePrintBedNode(bedX: bedX, bedY: bedY)
        bedNode.name = "printBed"
        scene.rootNode.addChildNode(bedNode)

        // XYZ axis gizmo at the front-left corner of the bed
        // Cura convention: X=right (red), Y=forward (green), Z=up (blue)
        let axesNode = makeAxesNode(bedX: bedX, bedY: bedY)
        axesNode.name = "axes"
        scene.rootNode.addChildNode(axesNode)

        // Mesh node — rotated to convert STL Z-up to SceneKit Y-up
        // STL/Cura: X=right, Y=forward, Z=up
        // SceneKit:  X=right, Z=toward viewer, Y=up
        // Rotation -90° around X maps STL Z→SceneKit Y and STL Y→SceneKit -Z
        let meshNode = SCNNode()
        meshNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        scene.rootNode.addChildNode(meshNode)
        context.coordinator.meshNode = meshNode

        // Lights
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 350
        ambientLight.color = UIColor.white
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)

        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = 800
        keyLight.color = UIColor(red: 1.0, green: 0.97, blue: 0.9, alpha: 1)
        let keyNode = SCNNode()
        keyNode.light = keyLight
        keyNode.eulerAngles = SCNVector3(-0.9, 0.5, 0)
        scene.rootNode.addChildNode(keyNode)

        // Camera — angled to see the full bed from a natural Cura-like perspective
        let bedDiag = Float(sqrt(bedX * bedX + bedY * bedY)) / 100
        let camera = SCNCamera()
        camera.zNear = 0.01
        camera.zFar  = 100
        camera.fieldOfView = 45
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(bedDiag * 0.75, bedDiag * 0.5, bedDiag)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
        scnView.pointOfView = cameraNode
        context.coordinator.cameraNode = cameraNode
        context.coordinator.lastBedX = bedX
        context.coordinator.lastBedY = bedY

        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        // Rebuild bed grid and axes if printer selection changed
        let bedChanged = context.coordinator.lastBedX != bedX || context.coordinator.lastBedY != bedY
        if bedChanged, let scene = scnView.scene {
            scene.rootNode.childNode(withName: "printBed", recursively: false)?.removeFromParentNode()
            scene.rootNode.childNode(withName: "axes", recursively: false)?.removeFromParentNode()
            let bedNode = makePrintBedNode(bedX: bedX, bedY: bedY)
            bedNode.name = "printBed"
            scene.rootNode.addChildNode(bedNode)
            let axesNode = makeAxesNode(bedX: bedX, bedY: bedY)
            axesNode.name = "axes"
            scene.rootNode.addChildNode(axesNode)
            context.coordinator.lastBedX = bedX
            context.coordinator.lastBedY = bedY
        }

        guard context.coordinator.lastGeometry !== geometry else { return }
        context.coordinator.lastGeometry = geometry

        guard let meshNode = context.coordinator.meshNode,
              let cam = context.coordinator.cameraNode else { return }

        meshNode.geometry = geometry

        guard let geo = geometry else { return }

        // The meshNode has eulerAngles = (-π/2, 0, 0), mapping STL axes to SceneKit:
        //   world.x =  local.x + pos.x
        //   world.y =  local.z + pos.y   ← STL Z (up) → SceneKit Y
        //   world.z = -local.y + pos.z   ← STL Y (forward) → SceneKit -Z
        //
        // We want:
        //   • Bottom of model at world Y = 0  → pos.y = -minBound.z
        //   • Model centered at world X = 0   → pos.x = -(minBound.x + maxBound.x) / 2
        //   • Model centered at world Z = 0   → pos.z =  (minBound.y + maxBound.y) / 2

        let (minB, maxB) = geo.boundingBox
        meshNode.position = SCNVector3(
            -(minB.x + maxB.x) / 2,
            -minB.z,
             (minB.y + maxB.y) / 2
        )

        // World-space center and size of the positioned model
        let modelHeight  = maxB.z - minB.z
        let modelExtentX = maxB.x - minB.x
        let modelExtentY = maxB.y - minB.y
        let maxExtent    = max(modelExtentX, modelExtentY, modelHeight)
        let lookAt       = SCNVector3(0, modelHeight / 2, 0)
        let dist         = max(maxExtent * 2.0, 0.8)

        cam.position = SCNVector3(dist * 0.75, modelHeight / 2 + dist * 0.5, dist)
        cam.look(at: lookAt)
        scnView.pointOfView = cam
        scnView.defaultCameraController.target = lookAt
    }
}

// MARK: - Print bed grid

// Scale: 1 SceneKit unit = 100 mm.
// Grid lines are spaced at ~20 mm intervals (divisions = bedSize / 20).
private func makePrintBedNode(bedX: Double, bedY: Double) -> SCNNode {
    let scaleX = Float(bedX) / 100
    let scaleZ = Float(bedY) / 100
    let halfX  = scaleX / 2
    let halfZ  = scaleZ / 2

    // Exactly 10 mm per cell
    let divX = max(Int(bedX / 10), 1)
    let divZ = max(Int(bedY / 10), 1)
    let stepX = scaleX / Float(divX)
    let stepZ = scaleZ / Float(divZ)

    var vertices: [SCNVector3] = []
    var indices:  [Int32]      = []
    var idx: Int32 = 0

    // Lines along X (constant Z)
    for i in 0...divZ {
        let z = -halfZ + Float(i) * stepZ
        vertices.append(SCNVector3(-halfX, 0, z)); vertices.append(SCNVector3(halfX, 0, z))
        indices.append(contentsOf: [idx, idx + 1]); idx += 2
    }
    // Lines along Z (constant X)
    for i in 0...divX {
        let x = -halfX + Float(i) * stepX
        vertices.append(SCNVector3(x, 0, -halfZ)); vertices.append(SCNVector3(x, 0, halfZ))
        indices.append(contentsOf: [idx, idx + 1]); idx += 2
    }

    let geo = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices)],
                          elements: [SCNGeometryElement(indices: indices, primitiveType: .line)])
    let mat = SCNMaterial()
    mat.diffuse.contents = UIColor(white: 0.38, alpha: 1)
    mat.lightingModel    = .constant
    geo.materials = [mat]
    return SCNNode(geometry: geo)
}

// MARK: - XYZ axis gizmo
// Cura convention rendered in SceneKit world space (mesh rotated -90° around X):
//   X (red)   → SceneKit +X
//   Y (green) → SceneKit -Z  (Cura forward, -90° rotation maps STL Y → SceneKit -Z)
//   Z (blue)  → SceneKit +Y  (Cura up,      -90° rotation maps STL Z → SceneKit +Y)

private func makeAxesNode(bedX: Double, bedY: Double) -> SCNNode {
    let root = SCNNode()

    // Scale arrow size proportionally to the bed (aim for ~15% of the shorter dimension)
    let shortSide = Float(min(bedX, bedY)) / 100
    let arrowScale = shortSide * 0.15

    let shaftLen: CGFloat = CGFloat(arrowScale)
    let shaftR:   CGFloat = CGFloat(arrowScale) * 0.05
    let headLen:  CGFloat = CGFloat(arrowScale) * 0.36
    let headR:    CGFloat = CGFloat(arrowScale) * 0.12

    // X — red, points in SceneKit +X
    root.addChildNode(arrow(shaft: shaftLen, shaftR: shaftR, head: headLen, headR: headR,
                            color: UIColor(red: 0.95, green: 0.2, blue: 0.2, alpha: 1),
                            euler: SCNVector3(0, 0, -Float.pi / 2)))
    // Y — green, points in SceneKit -Z (Cura Y = forward)
    root.addChildNode(arrow(shaft: shaftLen, shaftR: shaftR, head: headLen, headR: headR,
                            color: UIColor(red: 0.2, green: 0.85, blue: 0.3, alpha: 1),
                            euler: SCNVector3(-Float.pi / 2, 0, 0)))
    // Z — blue, points in SceneKit +Y (Cura Z = up)
    root.addChildNode(arrow(shaft: shaftLen, shaftR: shaftR, head: headLen, headR: headR,
                            color: UIColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1),
                            euler: SCNVector3(0, 0, 0)))

    // Place at front-left corner of bed, just above the plane
    let halfX = Float(bedX) / 200
    let halfZ = Float(bedY) / 200
    root.position = SCNVector3(-halfX, 0.01, halfZ)
    return root
}

private func arrow(shaft shaftLen: CGFloat, shaftR: CGFloat,
                   head headLen: CGFloat, headR: CGFloat,
                   color: UIColor, euler: SCNVector3) -> SCNNode {
    let mat = SCNMaterial()
    mat.diffuse.contents = color
    mat.lightingModel    = .constant

    // Shaft cylinder centred at origin along +Y
    let shaftGeo = SCNCylinder(radius: shaftR, height: shaftLen)
    shaftGeo.materials = [mat]
    let shaftNode = SCNNode(geometry: shaftGeo)
    shaftNode.position = SCNVector3(0, Float(shaftLen) / 2, 0)

    // Cone head above shaft
    let headGeo = SCNCone(topRadius: 0, bottomRadius: headR, height: headLen)
    headGeo.materials = [mat]
    let headNode = SCNNode(geometry: headGeo)
    headNode.position = SCNVector3(0, Float(shaftLen) + Float(headLen) / 2, 0)

    let arrowNode = SCNNode()
    arrowNode.addChildNode(shaftNode)
    arrowNode.addChildNode(headNode)
    arrowNode.eulerAngles = euler
    return arrowNode
}

// MARK: - Coordinator

final class Coordinator: NSObject {
    weak var meshNode:   SCNNode?
    weak var cameraNode: SCNNode?
    var lastGeometry: SCNGeometry? = nil
    var lastBedX: Double = 0
    var lastBedY: Double = 0
}
