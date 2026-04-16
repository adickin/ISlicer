import SceneKit
import SwiftUI

struct STLSceneView: UIViewRepresentable {
    let geometry: SCNGeometry?
    var bedX: Double = 220
    var bedY: Double = 220
    var showWireframe: Bool = false
    /// URL of the currently loaded STL — used to determine when to reset the camera.
    var stlURL: URL? = nil

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

        let bedNode = makePrintBedNode(bedX: bedX, bedY: bedY)
        bedNode.name = "printBed"
        scene.rootNode.addChildNode(bedNode)

        let axesNode = makeAxesNode(bedX: bedX, bedY: bedY)
        axesNode.name = "axes"
        scene.rootNode.addChildNode(axesNode)

        let meshNode = SCNNode()
        meshNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        scene.rootNode.addChildNode(meshNode)
        context.coordinator.meshNode = meshNode

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
        let coord = context.coordinator

        // 1. Rebuild bed grid and axes if printer dimensions changed
        let bedChanged = coord.lastBedX != bedX || coord.lastBedY != bedY
        if bedChanged, let scene = scnView.scene {
            scene.rootNode.childNode(withName: "printBed", recursively: false)?.removeFromParentNode()
            scene.rootNode.childNode(withName: "axes", recursively: false)?.removeFromParentNode()
            let bedNode = makePrintBedNode(bedX: bedX, bedY: bedY)
            bedNode.name = "printBed"
            scene.rootNode.addChildNode(bedNode)
            let axesNode = makeAxesNode(bedX: bedX, bedY: bedY)
            axesNode.name = "axes"
            scene.rootNode.addChildNode(axesNode)
            coord.lastBedX = bedX
            coord.lastBedY = bedY
        }

        guard let meshNode = coord.meshNode, let cam = coord.cameraNode else { return }

        // 2. Apply wireframe toggle even if geometry hasn't changed
        if coord.lastShowWireframe != showWireframe, let existingGeo = meshNode.geometry {
            applyWireframe(existingGeo, show: showWireframe)
            coord.lastShowWireframe = showWireframe
        }

        // 3. Nothing else to do if geometry is the same
        guard coord.lastGeometry !== geometry else { return }
        coord.lastGeometry = geometry
        meshNode.geometry = geometry

        // 4. Apply wireframe to the new geometry
        if let geo = geometry {
            applyWireframe(geo, show: showWireframe)
            coord.lastShowWireframe = showWireframe
        }

        guard let geo = geometry else { return }

        // 5. Position mesh on the bed (same logic for all colour modes — same vertices)
        let (minB, maxB) = geo.boundingBox
        meshNode.position = SCNVector3(
            -(minB.x + maxB.x) / 2,
            -minB.z,
             (minB.y + maxB.y) / 2
        )

        // 6. Reset camera only when the STL file itself changed (not just colour mode)
        let urlChanged = coord.lastSTLURL != stlURL
        coord.lastSTLURL = stlURL

        if urlChanged {
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

    private func applyWireframe(_ geo: SCNGeometry, show: Bool) {
        guard geo.materials.count > 1 else { return }
        geo.materials[1].transparency = show ? 1.0 : 0.0
    }
}

// MARK: - Print bed grid

// Scale: 1 SceneKit unit = 100 mm. Grid cells are 10 mm.
func makePrintBedNode(bedX: Double, bedY: Double) -> SCNNode {
    let scaleX = Float(bedX) / 100
    let scaleZ = Float(bedY) / 100
    let halfX  = scaleX / 2
    let halfZ  = scaleZ / 2

    let divX = max(Int(bedX / 10), 1)
    let divZ = max(Int(bedY / 10), 1)
    let stepX = scaleX / Float(divX)
    let stepZ = scaleZ / Float(divZ)

    var vertices: [SCNVector3] = []
    var indices:  [Int32]      = []
    var idx: Int32 = 0

    for i in 0...divZ {
        let z = -halfZ + Float(i) * stepZ
        vertices.append(SCNVector3(-halfX, 0, z)); vertices.append(SCNVector3(halfX, 0, z))
        indices.append(contentsOf: [idx, idx + 1]); idx += 2
    }
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

func makeAxesNode(bedX: Double, bedY: Double) -> SCNNode {
    let root = SCNNode()

    let shortSide = Float(min(bedX, bedY)) / 100
    let arrowScale = shortSide * 0.15

    let shaftLen: CGFloat = CGFloat(arrowScale)
    let shaftR:   CGFloat = CGFloat(arrowScale) * 0.05
    let headLen:  CGFloat = CGFloat(arrowScale) * 0.36
    let headR:    CGFloat = CGFloat(arrowScale) * 0.12

    root.addChildNode(arrow(shaft: shaftLen, shaftR: shaftR, head: headLen, headR: headR,
                            color: UIColor(red: 0.95, green: 0.2, blue: 0.2, alpha: 1),
                            euler: SCNVector3(0, 0, -Float.pi / 2)))
    root.addChildNode(arrow(shaft: shaftLen, shaftR: shaftR, head: headLen, headR: headR,
                            color: UIColor(red: 0.2, green: 0.85, blue: 0.3, alpha: 1),
                            euler: SCNVector3(-Float.pi / 2, 0, 0)))
    root.addChildNode(arrow(shaft: shaftLen, shaftR: shaftR, head: headLen, headR: headR,
                            color: UIColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1),
                            euler: SCNVector3(0, 0, 0)))

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

    let shaftGeo = SCNCylinder(radius: shaftR, height: shaftLen)
    shaftGeo.materials = [mat]
    let shaftNode = SCNNode(geometry: shaftGeo)
    shaftNode.position = SCNVector3(0, Float(shaftLen) / 2, 0)

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
    weak var meshNode:        SCNNode?
    weak var cameraNode:      SCNNode?
    var lastGeometry:         SCNGeometry? = nil
    var lastBedX:             Double = 0
    var lastBedY:             Double = 0
    var lastShowWireframe:    Bool = false
    var lastSTLURL:           URL? = nil
}
