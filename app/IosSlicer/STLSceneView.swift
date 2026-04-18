import SceneKit
import SwiftUI
import simd

// MARK: - Gizmo types

enum GizmoAxis {
    case x, y, z
    var worldDir: SIMD3<Float> {
        switch self { case .x: return SIMD3(1,0,0); case .y: return SIMD3(0,1,0); case .z: return SIMD3(0,0,1) }
    }
}

enum GizmoMode: Equatable { case translate, rotate, scale }

// MARK: - STLSceneView

struct STLSceneView: UIViewRepresentable {
    let geometry: SCNGeometry?
    var bedX: Double = 220
    var bedY: Double = 220
    var showWireframe: Bool = false
    var stlURL: URL? = nil
    var modelTransform: ModelTransform = .identity
    var gizmoMode: GizmoMode = .translate
    var onTransformChange: ((ModelTransform) -> Void)? = nil
    var onSelectionChange: ((Bool) -> Void)? = nil

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

        let pivotNode = SCNNode()
        pivotNode.name = "pivot"
        scene.rootNode.addChildNode(pivotNode)
        context.coordinator.pivotNode = pivotNode

        let meshNode = SCNNode()
        meshNode.name = "mesh"
        meshNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        pivotNode.addChildNode(meshNode)
        context.coordinator.meshNode = meshNode

        // Gizmo container — all three mode groups live here at unit scale.
        // We set container.scale to resize them all together.
        let container = SCNNode()
        container.name = "gizmoContainer"
        container.isHidden = true
        scene.rootNode.addChildNode(container)
        context.coordinator.gizmoContainerNode = container

        let tg = makeTranslateGizmo()
        tg.name = "gizmo_translate_group"
        container.addChildNode(tg)
        context.coordinator.gizmoTranslateGroup = tg

        let rg = makeRotateGizmo()
        rg.name = "gizmo_rotate_group"
        rg.isHidden = true
        container.addChildNode(rg)
        context.coordinator.gizmoRotateGroup = rg

        let sg = makeScaleGizmo()
        sg.name = "gizmo_scale_group"
        sg.isHidden = true
        container.addChildNode(sg)
        context.coordinator.gizmoScaleGroup = sg

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:)))
        tap.cancelsTouchesInView = false
        scnView.addGestureRecognizer(tap)
        context.coordinator.tapGesture = tap

        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleGizmoPan(_:)))
        pan.delegate = context.coordinator
        scnView.addGestureRecognizer(pan)
        context.coordinator.panGesture = pan

        let ambient = SCNLight(); ambient.type = .ambient; ambient.intensity = 350
        let ambNode = SCNNode(); ambNode.light = ambient
        scene.rootNode.addChildNode(ambNode)

        let key = SCNLight(); key.type = .directional; key.intensity = 800
        key.color = UIColor(red: 1.0, green: 0.97, blue: 0.9, alpha: 1)
        let keyNode = SCNNode(); keyNode.light = key
        keyNode.eulerAngles = SCNVector3(-0.9, 0.5, 0)
        scene.rootNode.addChildNode(keyNode)

        let bedDiag = Float(sqrt(bedX * bedX + bedY * bedY)) / 100
        let camera = SCNCamera(); camera.zNear = 0.01; camera.zFar = 100; camera.fieldOfView = 45
        let camNode = SCNNode(); camNode.camera = camera
        camNode.position = SCNVector3(bedDiag * 0.75, bedDiag * 0.5, bedDiag)
        camNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(camNode)
        scnView.pointOfView = camNode
        context.coordinator.cameraNode = camNode
        context.coordinator.lastBedX = bedX
        context.coordinator.lastBedY = bedY

        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        let coord = context.coordinator
        coord.onTransformChange    = onTransformChange
        coord.onSelectionChange    = onSelectionChange
        coord.currentTransform     = modelTransform

        // 1. Rebuild bed/axes on dimension change.
        if coord.lastBedX != bedX || coord.lastBedY != bedY, let scene = scnView.scene {
            scene.rootNode.childNode(withName: "printBed", recursively: false)?.removeFromParentNode()
            scene.rootNode.childNode(withName: "axes",     recursively: false)?.removeFromParentNode()
            let b = makePrintBedNode(bedX: bedX, bedY: bedY); b.name = "printBed"
            scene.rootNode.addChildNode(b)
            let a = makeAxesNode(bedX: bedX, bedY: bedY); a.name = "axes"
            scene.rootNode.addChildNode(a)
            coord.lastBedX = bedX; coord.lastBedY = bedY
        }

        // 2. Gizmo mode change — update group visibility.
        if coord.gizmoMode != gizmoMode {
            coord.gizmoMode = gizmoMode
            coord.updateGizmoGroupVisibility()
        }

        guard let meshNode = coord.meshNode, let cam = coord.cameraNode else { return }

        // 3. Apply user transform to pivot.
        if coord.lastTransform != modelTransform, let pivot = coord.pivotNode {
            let t = modelTransform
            let r = t.rotationDeg * (Float.pi / 180)
            pivot.position    = SCNVector3(t.positionMM.x / 100, t.positionMM.y / 100, t.positionMM.z / 100)
            pivot.eulerAngles = SCNVector3(r.x, r.y, r.z)
            pivot.scale       = SCNVector3(t.scale.x, t.scale.y, t.scale.z)
            coord.lastTransform = t
        }

        // 4. Keep gizmo centred on model.
        if let container = coord.gizmoContainerNode, let pivot = coord.pivotNode {
            container.position = pivot.convertPosition(
                SCNVector3(0, coord.modelHalfHeight, 0), to: nil)
        }

        // 5. Wireframe.
        if coord.lastShowWireframe != showWireframe, let geo = meshNode.geometry {
            applyWireframe(geo, show: showWireframe)
            coord.lastShowWireframe = showWireframe
        }

        // 6. No geometry change → done.
        guard coord.lastGeometry !== geometry else { return }

        coord.isModelSelected = false
        coord.updateGizmoGroupVisibility()   // hides container
        coord.lastGeometry = geometry
        meshNode.geometry = geometry

        if let geo = geometry {
            applyWireframe(geo, show: showWireframe)
            coord.lastShowWireframe = showWireframe
        }

        guard let geo = geometry else { return }

        // 7. Position mesh on bed.
        let (minB, maxB) = geo.boundingBox
        meshNode.position = SCNVector3(
            -(minB.x + maxB.x) / 2,
            -minB.z,
             (minB.y + maxB.y) / 2)

        // 8. Scale gizmo container proportionally to model.
        let modelDiag = simd_length(SIMD3<Float>(maxB.x - minB.x, maxB.y - minB.y, maxB.z - minB.z))
        coord.modelHalfHeight = (maxB.z - minB.z) / 2
        let s = max(modelDiag * 0.55, 0.06)
        coord.gizmoContainerNode?.scale = SCNVector3(s, s, s)

        // 9. Reset camera only when file changes.
        guard coord.lastSTLURL != stlURL else { return }
        coord.lastSTLURL = stlURL
        let modelH = maxB.z - minB.z
        let maxExt = max(maxB.x - minB.x, maxB.y - minB.y, modelH)
        let lookAt  = SCNVector3(0, modelH / 2, 0)
        let dist    = max(maxExt * 2.0, 0.8)
        cam.position = SCNVector3(dist * 0.75, modelH / 2 + dist * 0.5, dist)
        cam.look(at: lookAt)
        scnView.pointOfView = cam
        scnView.defaultCameraController.target = lookAt
    }

    private func applyWireframe(_ geo: SCNGeometry, show: Bool) {
        guard geo.materials.count > 1 else { return }
        geo.materials[1].transparency = show ? 1.0 : 0.0
    }
}

// MARK: - Gizmo builders (unit scale — container node is scaled externally)

/// Arrow shaft + cone tip, pointing along +Y, rotated by euler.
private func arrow(shaft: CGFloat, shaftR: CGFloat,
                   head: CGFloat, headR: CGFloat,
                   color: UIColor, euler: SCNVector3) -> SCNNode {
    let mat = SCNMaterial()
    mat.diffuse.contents = color
    mat.lightingModel = .constant

    let sg = SCNCylinder(radius: shaftR, height: shaft); sg.materials = [mat]
    let sn = SCNNode(geometry: sg); sn.position = SCNVector3(0, Float(shaft)/2, 0)

    let hg = SCNCone(topRadius: 0, bottomRadius: headR, height: head); hg.materials = [mat]
    let hn = SCNNode(geometry: hg); hn.position = SCNVector3(0, Float(shaft)+Float(head)/2, 0)

    let n = SCNNode(); n.addChildNode(sn); n.addChildNode(hn); n.eulerAngles = euler
    return n
}

private func makeTranslateGizmo() -> SCNNode {
    let shaft: CGFloat = 1.0, shaftR: CGFloat = 0.04
    let head:  CGFloat = 0.35, headR: CGFloat = 0.12
    let root = SCNNode()

    let xa = arrow(shaft: shaft, shaftR: shaftR, head: head, headR: headR,
                   color: UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1),
                   euler: SCNVector3(0, 0, -Float.pi/2))
    xa.name = "gizmo_x"

    let ya = arrow(shaft: shaft, shaftR: shaftR, head: head, headR: headR,
                   color: UIColor(red: 0.2, green: 0.9, blue: 0.2, alpha: 1),
                   euler: SCNVector3(0, 0, 0))
    ya.name = "gizmo_y"

    let za = arrow(shaft: shaft, shaftR: shaftR, head: head, headR: headR,
                   color: UIColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1),
                   euler: SCNVector3(Float.pi/2, 0, 0))
    za.name = "gizmo_z"

    root.addChildNode(xa); root.addChildNode(ya); root.addChildNode(za)
    return root
}

/// A torus ring node. pipeHit is a wider invisible torus used as the tap target.
private func ringNode(ringR: CGFloat, pipeVis: CGFloat, color: UIColor, euler: SCNVector3) -> SCNNode {
    // Invisible wide torus for easier hit-testing
    let hitGeo = SCNTorus(ringRadius: ringR, pipeRadius: pipeVis * 3)
    let hitMat = SCNMaterial()
    hitMat.diffuse.contents = UIColor.clear
    hitMat.lightingModel = .constant
    hitGeo.materials = [hitMat]
    let n = SCNNode(geometry: hitGeo)
    n.eulerAngles = euler

    // Visible thin torus
    let visGeo = SCNTorus(ringRadius: ringR, pipeRadius: pipeVis)
    let visMat = SCNMaterial()
    visMat.diffuse.contents = color
    visMat.lightingModel = .constant
    visGeo.materials = [visMat]
    n.addChildNode(SCNNode(geometry: visGeo))

    return n
}

private func makeRotateGizmo() -> SCNNode {
    let ringR: CGFloat = 0.65, pipeVis: CGFloat = 0.045
    let root = SCNNode()

    // X: ring in YZ plane — rotate torus (Y-axis hole) so hole aligns with X: Rz(+90°)
    let xr = ringNode(ringR: ringR, pipeVis: pipeVis,
                      color: UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1),
                      euler: SCNVector3(0, 0, Float.pi/2))
    xr.name = "gizmo_rot_x"

    // Y: ring in XZ plane — default SCNTorus
    let yr = ringNode(ringR: ringR, pipeVis: pipeVis,
                      color: UIColor(red: 0.2, green: 0.9, blue: 0.2, alpha: 1),
                      euler: SCNVector3(0, 0, 0))
    yr.name = "gizmo_rot_y"

    // Z: ring in XY plane — Rx(+90°) so hole aligns with Z
    let zr = ringNode(ringR: ringR, pipeVis: pipeVis,
                      color: UIColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1),
                      euler: SCNVector3(Float.pi/2, 0, 0))
    zr.name = "gizmo_rot_z"

    root.addChildNode(xr); root.addChildNode(yr); root.addChildNode(zr)
    return root
}

/// Shaft + cube tip, pointing along +Y, rotated by euler.
private func scaleHandle(shaft: CGFloat, shaftR: CGFloat, cube: CGFloat,
                          color: UIColor, euler: SCNVector3) -> SCNNode {
    let mat = SCNMaterial()
    mat.diffuse.contents = color
    mat.lightingModel = .constant

    let sg = SCNCylinder(radius: shaftR, height: shaft); sg.materials = [mat]
    let sn = SCNNode(geometry: sg); sn.position = SCNVector3(0, Float(shaft)/2, 0)

    let cg = SCNBox(width: cube, height: cube, length: cube, chamferRadius: 0.02*cube)
    cg.materials = [mat]
    let cn = SCNNode(geometry: cg); cn.position = SCNVector3(0, Float(shaft)+Float(cube)/2, 0)

    let n = SCNNode(); n.addChildNode(sn); n.addChildNode(cn); n.eulerAngles = euler
    return n
}

private func makeScaleGizmo() -> SCNNode {
    let shaft: CGFloat = 1.0, shaftR: CGFloat = 0.04, cube: CGFloat = 0.18
    let root = SCNNode()

    let xa = scaleHandle(shaft: shaft, shaftR: shaftR, cube: cube,
                          color: UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1),
                          euler: SCNVector3(0, 0, -Float.pi/2))
    xa.name = "gizmo_scale_x"

    let ya = scaleHandle(shaft: shaft, shaftR: shaftR, cube: cube,
                          color: UIColor(red: 0.2, green: 0.9, blue: 0.2, alpha: 1),
                          euler: SCNVector3(0, 0, 0))
    ya.name = "gizmo_scale_y"

    let za = scaleHandle(shaft: shaft, shaftR: shaftR, cube: cube,
                          color: UIColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1),
                          euler: SCNVector3(Float.pi/2, 0, 0))
    za.name = "gizmo_scale_z"

    root.addChildNode(xa); root.addChildNode(ya); root.addChildNode(za)
    return root
}

// MARK: - Print bed grid

func makePrintBedNode(bedX: Double, bedY: Double) -> SCNNode {
    let scaleX = Float(bedX) / 100, scaleZ = Float(bedY) / 100
    let halfX = scaleX / 2,         halfZ = scaleZ / 2
    let divX = max(Int(bedX / 10), 1), divZ = max(Int(bedY / 10), 1)
    let stepX = scaleX / Float(divX), stepZ = scaleZ / Float(divZ)

    var verts: [SCNVector3] = []; var idx: [Int32] = []; var i32: Int32 = 0
    for i in 0...divZ {
        let z = -halfZ + Float(i) * stepZ
        verts += [SCNVector3(-halfX,0,z), SCNVector3(halfX,0,z)]
        idx += [i32, i32+1]; i32 += 2
    }
    for i in 0...divX {
        let x = -halfX + Float(i) * stepX
        verts += [SCNVector3(x,0,-halfZ), SCNVector3(x,0,halfZ)]
        idx += [i32, i32+1]; i32 += 2
    }
    let geo = SCNGeometry(sources: [SCNGeometrySource(vertices: verts)],
                          elements: [SCNGeometryElement(indices: idx, primitiveType: .line)])
    let mat = SCNMaterial(); mat.diffuse.contents = UIColor(white: 0.38, alpha: 1); mat.lightingModel = .constant
    geo.materials = [mat]
    return SCNNode(geometry: geo)
}

// MARK: - Corner axis arrows

func makeAxesNode(bedX: Double, bedY: Double) -> SCNNode {
    let root = SCNNode()
    let short = Float(min(bedX, bedY)) / 100
    let s = short * 0.15
    let sl: CGFloat = CGFloat(s), sr: CGFloat = CGFloat(s)*0.05
    let hl: CGFloat = CGFloat(s)*0.36, hr: CGFloat = CGFloat(s)*0.12

    root.addChildNode(arrow(shaft: sl, shaftR: sr, head: hl, headR: hr,
                            color: UIColor(red: 0.95, green: 0.2, blue: 0.2, alpha: 1),
                            euler: SCNVector3(0, 0, -Float.pi/2)))
    root.addChildNode(arrow(shaft: sl, shaftR: sr, head: hl, headR: hr,
                            color: UIColor(red: 0.2, green: 0.85, blue: 0.3, alpha: 1),
                            euler: SCNVector3(-Float.pi/2, 0, 0)))
    root.addChildNode(arrow(shaft: sl, shaftR: sr, head: hl, headR: hr,
                            color: UIColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1),
                            euler: SCNVector3(0, 0, 0)))
    root.position = SCNVector3(-Float(bedX)/200, 0.01, Float(bedY)/200)
    return root
}

// MARK: - Coordinator

final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    // Scene nodes
    weak var pivotNode:           SCNNode?
    weak var meshNode:            SCNNode?
    weak var cameraNode:          SCNNode?
    weak var gizmoContainerNode:  SCNNode?
    weak var gizmoTranslateGroup: SCNNode?
    weak var gizmoRotateGroup:    SCNNode?
    weak var gizmoScaleGroup:     SCNNode?

    // State
    var lastGeometry:      SCNGeometry? = nil
    var lastBedX:          Double = 0
    var lastBedY:          Double = 0
    var lastShowWireframe: Bool = false
    var lastSTLURL:        URL? = nil
    var lastTransform:     ModelTransform = .identity
    var modelHalfHeight:   Float = 0

    // Selection
    var isModelSelected:   Bool = false

    // Gizmo mode
    var gizmoMode:         GizmoMode = .translate

    // Drag state
    weak var tapGesture:   UITapGestureRecognizer?
    weak var panGesture:   UIPanGestureRecognizer?
    var dragAxis:          GizmoAxis? = nil
    var dragMode:          GizmoMode = .translate
    var lastPanLocation:   CGPoint? = nil
    var currentTransform:  ModelTransform = .identity

    // Callbacks
    var onTransformChange: ((ModelTransform) -> Void)? = nil
    var onSelectionChange: ((Bool) -> Void)? = nil

    // MARK: Group visibility

    func updateGizmoGroupVisibility() {
        let show = isModelSelected && meshNode?.geometry != nil
        gizmoContainerNode?.isHidden = !show
        guard show else { return }
        gizmoTranslateGroup?.isHidden = gizmoMode != .translate
        gizmoRotateGroup?.isHidden    = gizmoMode != .rotate
        gizmoScaleGroup?.isHidden     = gizmoMode != .scale
    }

    // MARK: Gesture delegate

    func gestureRecognizerShouldBegin(_ gr: UIGestureRecognizer) -> Bool {
        guard gr === panGesture,
              let scnView = gr.view as? SCNView,
              isModelSelected,
              gizmoContainerNode?.isHidden == false else { return false }
        let hits = scnView.hitTest(gr.location(in: scnView), options: nil)
        return gizmoNodeInfo(hits.first?.node) != nil
    }

    func gestureRecognizer(_ gr: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        return gr === panGesture || other === panGesture
    }

    // MARK: Tap

    @objc func handleTap(_ tap: UITapGestureRecognizer) {
        guard let scnView = tap.view as? SCNView else { return }
        let hits = scnView.hitTest(tap.location(in: scnView), options: nil)
        let hit  = hits.first?.node
        if gizmoNodeInfo(hit) != nil { return }  // tapping gizmo doesn't change selection
        setSelected(isPartOfModel(hit))
    }

    private func setSelected(_ sel: Bool) {
        isModelSelected = sel
        updateGizmoGroupVisibility()
        onSelectionChange?(sel)
    }

    // MARK: Pan

    @objc func handleGizmoPan(_ gesture: UIPanGestureRecognizer) {
        guard let scnView = gesture.view as? SCNView else { return }

        switch gesture.state {
        case .began:
            let loc  = gesture.location(in: scnView)
            let hits = scnView.hitTest(loc, options: nil)
            if let info = gizmoNodeInfo(hits.first?.node) {
                dragAxis = info.axis
                dragMode = info.mode
                lastPanLocation = loc
                scnView.allowsCameraControl = false
            }

        case .changed:
            guard let axis = dragAxis,
                  let last = lastPanLocation,
                  let pivot = pivotNode else { return }

            let cur   = gesture.location(in: scnView)
            let delta = CGPoint(x: cur.x - last.x, y: cur.y - last.y)
            lastPanLocation = cur

            var t = currentTransform
            switch dragMode {
            case .translate:
                let dm = axisDeltaMM(screenDelta: delta, dir: axis.worldDir,
                                     in: scnView, origin: pivot.worldPosition)
                switch axis {
                case .x: t.positionMM.x += dm
                case .y: t.positionMM.y += dm
                case .z: t.positionMM.z += dm
                }

            case .rotate:
                let deg = rotateAngleDeg(screenDelta: delta, axis: axis.worldDir,
                                         in: scnView, origin: pivot.worldPosition)
                switch axis {
                case .x: t.rotationDeg.x += deg
                case .y: t.rotationDeg.y += deg
                case .z: t.rotationDeg.z += deg
                }

            case .scale:
                let proj = axisScreenPx(screenDelta: delta, dir: axis.worldDir,
                                        in: scnView, origin: pivot.worldPosition)
                // Per-axis scale: dragging 200 px doubles that axis.
                let mult = max(0.001, 1.0 + proj / 200.0)
                switch axis {
                case .x: t.scale.x = max(0.001, t.scale.x * mult)
                case .y: t.scale.y = max(0.001, t.scale.y * mult)
                case .z: t.scale.z = max(0.001, t.scale.z * mult)
                }
            }

            currentTransform = t
            onTransformChange?(t)

        case .ended, .cancelled:
            dragAxis = nil
            lastPanLocation = nil
            scnView.allowsCameraControl = true

        default: break
        }
    }

    // MARK: Helpers

    private func gizmoNodeInfo(_ node: SCNNode?) -> (axis: GizmoAxis, mode: GizmoMode)? {
        var n = node
        while let cur = n {
            switch cur.name {
            case "gizmo_x":       return (.x, .translate)
            case "gizmo_y":       return (.y, .translate)
            case "gizmo_z":       return (.z, .translate)
            case "gizmo_rot_x":   return (.x, .rotate)
            case "gizmo_rot_y":   return (.y, .rotate)
            case "gizmo_rot_z":   return (.z, .rotate)
            case "gizmo_scale_x": return (.x, .scale)
            case "gizmo_scale_y": return (.y, .scale)
            case "gizmo_scale_z": return (.z, .scale)
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

    /// Screen-space dot-projection of drag onto world axis. Returns mm.
    private func axisDeltaMM(screenDelta: CGPoint, dir: SIMD3<Float>,
                              in v: SCNView, origin: SCNVector3) -> Float {
        let p0 = v.projectPoint(origin)
        let p1 = v.projectPoint(SCNVector3(origin.x+dir.x, origin.y+dir.y, origin.z+dir.z))
        let sx = CGFloat(p1.x-p0.x), sy = CGFloat(p1.y-p0.y)
        let sq = sx*sx + sy*sy
        guard sq > 0.01 else { return 0 }
        return Float((screenDelta.x*sx + screenDelta.y*sy) / sq) * 100
    }

    /// Screen-space dot-projection of drag onto world axis. Returns raw pixels.
    private func axisScreenPx(screenDelta: CGPoint, dir: SIMD3<Float>,
                               in v: SCNView, origin: SCNVector3) -> Float {
        let p0 = v.projectPoint(origin)
        let p1 = v.projectPoint(SCNVector3(origin.x+dir.x, origin.y+dir.y, origin.z+dir.z))
        let sx = CGFloat(p1.x-p0.x), sy = CGFloat(p1.y-p0.y)
        let len = sqrt(sx*sx + sy*sy)
        guard len > 0.1 else { return 0 }
        return Float((screenDelta.x*sx + screenDelta.y*sy) / len)
    }

    /// Projects drag onto the screen-space perpendicular of the axis. Returns degrees.
    private func rotateAngleDeg(screenDelta: CGPoint, axis: SIMD3<Float>,
                                 in v: SCNView, origin: SCNVector3) -> Float {
        let p0 = v.projectPoint(origin)
        let p1 = v.projectPoint(SCNVector3(origin.x+axis.x, origin.y+axis.y, origin.z+axis.z))
        // Perpendicular to screen-projected axis
        let px = -(CGFloat(p1.y-p0.y))
        let py =   CGFloat(p1.x-p0.x)
        let plen = sqrt(px*px + py*py)
        guard plen > 0.1 else { return 0 }
        let proj = (screenDelta.x*px + screenDelta.y*py) / plen
        return Float(proj) * 0.3   // 0.3 degrees per pixel
    }
}
