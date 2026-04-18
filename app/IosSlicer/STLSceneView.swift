import SceneKit
import SwiftUI
import simd

// MARK: - Gizmo axis

enum GizmoAxis {
    case x, y, z

    var worldDir: SIMD3<Float> {
        switch self {
        case .x: return SIMD3(1, 0, 0)
        case .y: return SIMD3(0, 1, 0)
        case .z: return SIMD3(0, 0, 1)
        }
    }
}

// MARK: - STLSceneView

struct STLSceneView: UIViewRepresentable {
    let geometry: SCNGeometry?
    var bedX: Double = 220
    var bedY: Double = 220
    var showWireframe: Bool = false
    var stlURL: URL? = nil
    var modelTransform: ModelTransform = .identity
    /// Called whenever a gizmo drag changes the transform.
    var onTransformChange: ((ModelTransform) -> Void)? = nil

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

        // pivotNode receives the user transform; meshNode is its child.
        let pivotNode = SCNNode()
        pivotNode.name = "pivot"
        scene.rootNode.addChildNode(pivotNode)
        context.coordinator.pivotNode = pivotNode

        let meshNode = SCNNode()
        meshNode.name = "mesh"
        meshNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        pivotNode.addChildNode(meshNode)
        context.coordinator.meshNode = meshNode

        // Translate gizmo — parented to scene root so arrows stay world-aligned.
        let gizmoRoot = makeTranslateGizmo(scale: 0.15)
        gizmoRoot.name = "gizmoRoot"
        gizmoRoot.isHidden = true
        scene.rootNode.addChildNode(gizmoRoot)
        context.coordinator.gizmoRootNode = gizmoRoot

        // Tap: select model / deselect on background.
        // cancelsTouchesInView=false so SceneKit's internal recognisers are unaffected.
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:)))
        tap.cancelsTouchesInView = false
        scnView.addGestureRecognizer(tap)
        context.coordinator.tapGesture = tap

        // Pan: drag gizmo arrows. Uses delegate so it only begins when an arrow is hit,
        // letting SceneKit's orbit pan run freely the rest of the time.
        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleGizmoPan(_:)))
        pan.delegate = context.coordinator
        scnView.addGestureRecognizer(pan)
        context.coordinator.panGesture = pan

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
        coord.onTransformChange = onTransformChange
        coord.currentTransform  = modelTransform

        // 1. Rebuild bed/axes when printer dimensions change.
        let bedChanged = coord.lastBedX != bedX || coord.lastBedY != bedY
        if bedChanged, let scene = scnView.scene {
            scene.rootNode.childNode(withName: "printBed", recursively: false)?.removeFromParentNode()
            scene.rootNode.childNode(withName: "axes",     recursively: false)?.removeFromParentNode()
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

        // 2. Apply user transform to pivot node.
        if coord.lastTransform != modelTransform, let pivot = coord.pivotNode {
            let t = modelTransform
            let r = t.rotationDeg * (Float.pi / 180)
            pivot.position    = SCNVector3(t.positionMM.x / 100, t.positionMM.y / 100, t.positionMM.z / 100)
            pivot.eulerAngles = SCNVector3(r.x, r.y, r.z)
            pivot.scale       = SCNVector3(t.scale.x, t.scale.y, t.scale.z)
            coord.lastTransform = t
        }

        // Keep gizmo centred on the model in world space.
        if let gizmo = coord.gizmoRootNode, let pivot = coord.pivotNode {
            gizmo.position = pivot.convertPosition(
                SCNVector3(0, coord.modelHalfHeight, 0), to: nil)
        }

        // 3. Apply wireframe toggle on existing geometry.
        if coord.lastShowWireframe != showWireframe, let existingGeo = meshNode.geometry {
            applyWireframe(existingGeo, show: showWireframe)
            coord.lastShowWireframe = showWireframe
        }

        // 4. No geometry change → nothing more to do.
        guard coord.lastGeometry !== geometry else { return }

        // New model loaded — deselect and hide gizmo.
        coord.isModelSelected = false
        coord.gizmoRootNode?.isHidden = true

        coord.lastGeometry = geometry
        meshNode.geometry = geometry

        // 5. Apply wireframe to newly assigned geometry.
        if let geo = geometry {
            applyWireframe(geo, show: showWireframe)
            coord.lastShowWireframe = showWireframe
        }

        guard let geo = geometry else { return }

        // 6. Position mesh on the bed.
        let (minB, maxB) = geo.boundingBox
        meshNode.position = SCNVector3(
            -(minB.x + maxB.x) / 2,
            -minB.z,
             (minB.y + maxB.y) / 2
        )

        // 7. Rescale gizmo proportionally to the model.
        let modelDiag = simd_length(SIMD3<Float>(
            maxB.x - minB.x, maxB.y - minB.y, maxB.z - minB.z))
        coord.modelHalfHeight = (maxB.z - minB.z) / 2
        updateGizmoScale(coord.gizmoRootNode, scale: max(modelDiag * 0.55, 0.06))

        // 8. Reset camera only when the STL file changed.
        guard coord.lastSTLURL != stlURL else { return }
        coord.lastSTLURL = stlURL

        let modelHeight = maxB.z - minB.z
        let maxExtent   = max(maxB.x - minB.x, maxB.y - minB.y, modelHeight)
        let lookAt      = SCNVector3(0, modelHeight / 2, 0)
        let dist        = max(maxExtent * 2.0, 0.8)
        cam.position = SCNVector3(dist * 0.75, modelHeight / 2 + dist * 0.5, dist)
        cam.look(at: lookAt)
        scnView.pointOfView = cam
        scnView.defaultCameraController.target = lookAt
    }

    private func applyWireframe(_ geo: SCNGeometry, show: Bool) {
        guard geo.materials.count > 1 else { return }
        geo.materials[1].transparency = show ? 1.0 : 0.0
    }

    private func updateGizmoScale(_ gizmoRoot: SCNNode?, scale s: Float) {
        guard let root = gizmoRoot else { return }
        let shaft   = CGFloat(s)
        let shaftR  = CGFloat(s * 0.07)
        let headLen = CGFloat(s * 0.4)
        let headR   = CGFloat(s * 0.18)

        for child in root.childNodes {
            let kids = child.childNodes
            guard kids.count == 2 else { continue }
            if let cyl  = kids[0].geometry as? SCNCylinder { cyl.height = shaft; cyl.radius = shaftR }
            kids[0].position = SCNVector3(0, Float(shaft) / 2, 0)
            if let cone = kids[1].geometry as? SCNCone { cone.height = headLen; cone.bottomRadius = headR }
            kids[1].position = SCNVector3(0, Float(shaft) + Float(headLen) / 2, 0)
        }
    }
}

// MARK: - Translate gizmo builder

private func makeTranslateGizmo(scale s: Float) -> SCNNode {
    let root    = SCNNode()
    let shaft   = CGFloat(s)
    let shaftR  = CGFloat(s * 0.07)
    let headLen = CGFloat(s * 0.4)
    let headR   = CGFloat(s * 0.18)

    // X: red — rotate +Y cylinder to +X
    let xa = arrow(shaft: shaft, shaftR: shaftR, head: headLen, headR: headR,
                   color: UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1),
                   euler: SCNVector3(0, 0, -Float.pi / 2))
    xa.name = "gizmo_x"

    // Y: green — already points +Y
    let ya = arrow(shaft: shaft, shaftR: shaftR, head: headLen, headR: headR,
                   color: UIColor(red: 0.2, green: 0.9, blue: 0.2, alpha: 1),
                   euler: SCNVector3(0, 0, 0))
    ya.name = "gizmo_y"

    // Z: blue — rotate +Y cylinder to +Z
    let za = arrow(shaft: shaft, shaftR: shaftR, head: headLen, headR: headR,
                   color: UIColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1),
                   euler: SCNVector3(Float.pi / 2, 0, 0))
    za.name = "gizmo_z"

    root.addChildNode(xa)
    root.addChildNode(ya)
    root.addChildNode(za)
    return root
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

// MARK: - Corner axis gizmo

func makeAxesNode(bedX: Double, bedY: Double) -> SCNNode {
    let root = SCNNode()
    let shortSide  = Float(min(bedX, bedY)) / 100
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

// MARK: - Arrow primitive

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

final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    // Scene nodes
    weak var pivotNode:      SCNNode?
    weak var meshNode:       SCNNode?
    weak var cameraNode:     SCNNode?
    weak var gizmoRootNode:  SCNNode?

    // State tracking
    var lastGeometry:        SCNGeometry? = nil
    var lastBedX:            Double = 0
    var lastBedY:            Double = 0
    var lastShowWireframe:   Bool = false
    var lastSTLURL:          URL? = nil
    var lastTransform:       ModelTransform = .identity

    // Selection
    var isModelSelected:     Bool = false

    // Gizmo drag state
    weak var tapGesture:     UITapGestureRecognizer?
    weak var panGesture:     UIPanGestureRecognizer?
    var selectedGizmoAxis:   GizmoAxis? = nil
    var lastPanLocation:     CGPoint? = nil
    var currentTransform:    ModelTransform = .identity
    var modelHalfHeight:     Float = 0
    var onTransformChange:   ((ModelTransform) -> Void)? = nil

    // MARK: UIGestureRecognizerDelegate

    /// Allow the gizmo pan to run simultaneously alongside SceneKit's internal orbit pan,
    /// but only actually begin if the touch starts on a gizmo arrow (see handleGizmoPan).
    func gestureRecognizerShouldBegin(_ gr: UIGestureRecognizer) -> Bool {
        guard gr === panGesture,
              let scnView = gr.view as? SCNView,
              isModelSelected,
              gizmoRootNode?.isHidden == false else { return false }

        let loc  = gr.location(in: scnView)
        let hits = scnView.hitTest(loc, options: nil)
        return gizmoAxisFromNode(hits.first?.node) != nil
    }

    func gestureRecognizer(_ gr: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        // Let the gizmo pan coexist with SceneKit's internal recognisers.
        return gr === panGesture || other === panGesture
    }

    // MARK: Tap — select / deselect

    @objc func handleTap(_ tap: UITapGestureRecognizer) {
        guard let scnView = tap.view as? SCNView else { return }
        let loc  = tap.location(in: scnView)
        let hits = scnView.hitTest(loc, options: nil)
        let hit  = hits.first?.node

        // Tapping a gizmo arrow should not affect selection.
        if gizmoAxisFromNode(hit) != nil { return }

        let hitModel = isPartOfModel(hit)
        setSelected(hitModel)
    }

    private func setSelected(_ selected: Bool) {
        isModelSelected = selected
        gizmoRootNode?.isHidden = !selected || meshNode?.geometry == nil
    }

    // MARK: Pan — drag along selected axis

    @objc func handleGizmoPan(_ gesture: UIPanGestureRecognizer) {
        guard let scnView = gesture.view as? SCNView else { return }

        switch gesture.state {
        case .began:
            let loc  = gesture.location(in: scnView)
            let hits = scnView.hitTest(loc, options: nil)
            selectedGizmoAxis = gizmoAxisFromNode(hits.first?.node)
            lastPanLocation   = loc
            // Lock camera so orbit doesn't fight the drag.
            scnView.allowsCameraControl = false

        case .changed:
            guard let axis  = selectedGizmoAxis,
                  let last  = lastPanLocation,
                  let pivot = pivotNode else { return }

            let current = gesture.location(in: scnView)
            let delta   = CGPoint(x: current.x - last.x, y: current.y - last.y)
            lastPanLocation = current

            let deltaMM = axisDeltaMM(screenDelta: delta, dir: axis.worldDir,
                                      in: scnView, origin: pivot.worldPosition)
            var t = currentTransform
            switch axis {
            case .x: t.positionMM.x += deltaMM
            case .y: t.positionMM.y += deltaMM
            case .z: t.positionMM.z += deltaMM
            }
            currentTransform = t
            onTransformChange?(t)

        case .ended, .cancelled:
            selectedGizmoAxis = nil
            lastPanLocation   = nil
            // Restore camera orbit.
            scnView.allowsCameraControl = true

        default: break
        }
    }

    // MARK: Helpers

    private func gizmoAxisFromNode(_ node: SCNNode?) -> GizmoAxis? {
        var n = node
        while let cur = n {
            switch cur.name {
            case "gizmo_x": return .x
            case "gizmo_y": return .y
            case "gizmo_z": return .z
            default: n = cur.parent
            }
        }
        return nil
    }

    private func isPartOfModel(_ node: SCNNode?) -> Bool {
        var n = node
        while let cur = n {
            if cur === meshNode || cur === pivotNode { return true }
            n = cur.parent
        }
        return false
    }

    /// Projects a screen-space drag delta onto a world-space axis direction; returns mm movement.
    private func axisDeltaMM(screenDelta: CGPoint, dir: SIMD3<Float>,
                              in scnView: SCNView, origin: SCNVector3) -> Float {
        let p0 = scnView.projectPoint(origin)
        let p1 = scnView.projectPoint(SCNVector3(origin.x + dir.x, origin.y + dir.y, origin.z + dir.z))

        let sx   = CGFloat(p1.x - p0.x)
        let sy   = CGFloat(p1.y - p0.y)
        let lenSq = sx * sx + sy * sy
        guard lenSq > 0.01 else { return 0 }

        return Float((screenDelta.x * sx + screenDelta.y * sy) / lenSq) * 100
    }
}
