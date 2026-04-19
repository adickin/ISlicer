import SwiftUI
import UIKit
import UniformTypeIdentifiers
import SceneKit

// MARK: - State

enum SliceState {
    case idle
    case slicing(phase: String, progress: Double)
    case done(gcodeURL: URL, printTime: String?, filamentG: String?)
    case failed(message: String)
}

// MARK: - Progress relay
// Boxes a Swift closure so it can be passed as a C void* context pointer.

private final class ProgressRelay: @unchecked Sendable {
    var handler: (Float) -> Void = { _ in }
}

// MARK: - ContentView

struct ContentView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @EnvironmentObject var sliceProfileStore: SliceProfileStore
    @EnvironmentObject var materialProfileStore: MaterialProfileStore

    @State private var state: SliceState = .idle
    @State private var showShareSheet = false
    @State private var showFilePicker = false
    @State private var showErrorAlert = false
    @State private var showProfilePicker = false
    @State private var showSliceProfilePicker = false
    @State private var showMaterialProfilePicker = false
    @State private var showNoProfileAlert = false
    @State private var showNoSliceProfileAlert = false
    @State private var isPanelExpanded = true

    // Model transform + gizmo
    @State private var modelTransform = ModelTransform()
    @State private var showTransformPanel = false
    @State private var stlMeshInfo: STLMeshInfo? = nil
    @State private var gizmoMode: GizmoMode = .translate
    @State private var isModelSelected = false
    @State private var lockScale = true

    /// URL of the STL that has been copied to the temp directory.
    @State private var loadedSTLURL: URL? = nil
    @State private var loadedSTLName: String = "None"

    /// SceneKit geometry for the 3D preview.
    @State private var loadedSTLGeometry: SCNGeometry? = nil
    @State private var isParsingSTL = false

    // Viewer controls
    @State private var showWireframe: Bool = false
    @State private var viewerColorMode: ViewerColorMode = .solid

    // Layer preview
    @State private var showLayerPreview: Bool = false
    @State private var parsedLayers: [GCodeLayer] = []
    @State private var currentLayerIndex: Int = 0

    /// Retained while a slice is in progress; lets the cancel button reach slicer_cancel().
    @State private var activeHandle: SlicerHandle? = nil

    private var isBusy: Bool {
        if case .slicing = state { return true }
        return false
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-screen viewer — STL or GCode layer preview
            Group {
                if showLayerPreview && !parsedLayers.isEmpty {
                    GCodeSceneView(
                        layers: parsedLayers,
                        currentLayerIndex: currentLayerIndex,
                        bedX: profileStore.selectedProfile?.bedX ?? 220,
                        bedY: profileStore.selectedProfile?.bedY ?? 220
                    )
                } else {
                    STLSceneView(
                        geometry: loadedSTLGeometry,
                        bedX: profileStore.selectedProfile?.bedX ?? 220,
                        bedY: profileStore.selectedProfile?.bedY ?? 220,
                        showWireframe: showWireframe,
                        stlURL: loadedSTLURL,
                        modelTransform: modelTransform,
                        gizmoMode: gizmoMode,
                        lockScale: lockScale,
                        onTransformChange: { modelTransform = $0 },
                        onSelectionChange: { isModelSelected = $0 }
                    )
                    .overlay {
                        if isParsingSTL {
                            Color(.systemGray6).opacity(0.7)
                                .overlay { ProgressView("Loading…") }
                        }
                    }
                }
            }
            .ignoresSafeArea()

            // Viewer controls overlay — top-right floating buttons
            viewerControlsOverlay

            // Layer slider — shown above the panel when in layer preview mode
            if showLayerPreview && !parsedLayers.isEmpty {
                layerSliderView
            }

            // Bottom panel
            bottomPanel
        }
        .ignoresSafeArea(edges: .top)
        .onChange(of: viewerColorMode) { _ in
            // Re-parse with new colour mode; camera is NOT reset (same URL)
            if let url = loadedSTLURL { parseSTLPreview(url: url) }
        }
        .sheet(isPresented: $showFilePicker) {
            DocumentPickerView { url in importSTL(from: url) }
        }
        .sheet(isPresented: $showShareSheet) {
            if case .done(let url, _, _) = state {
                ShareSheetView(items: [url]).ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showProfilePicker) {
            ProfilePickerView()
        }
        .sheet(isPresented: $showSliceProfilePicker) {
            SliceProfilePickerView()
        }
        .sheet(isPresented: $showMaterialProfilePicker) {
            MaterialProfilePickerView()
        }
        .sheet(isPresented: $showTransformPanel) {
            TransformPanelView(
                transform: $modelTransform,
                meshInfo: stlMeshInfo,
                bedX: profileStore.selectedProfile?.bedX ?? 220,
                bedY: profileStore.selectedProfile?.bedY ?? 220,
                bedZ: profileStore.selectedProfile?.bedZ ?? 250,
                lockScale: $lockScale
            )
        }
        .alert("Slicing Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if case .failed(let msg) = state { Text(msg) }
        }
        .alert("No Printer Selected", isPresented: $showNoProfileAlert) {
            Button("Choose Printer") { showProfilePicker = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please select a printer profile before slicing.")
        }
        .alert("No Slice Profile Selected", isPresented: $showNoSliceProfileAlert) {
            Button("Choose Profile") { showSliceProfilePicker = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please select a slice profile before slicing.")
        }
    }

    // MARK: - Viewer controls overlay

    private var viewerControlsOverlay: some View {
        VStack {
            HStack(alignment: .top) {
                // LEFT: Live transform bar (position/rotation/scale fields)
                if !showLayerPreview && isModelSelected && loadedSTLGeometry != nil {
                    transformBarContent
                        .padding(.leading, 16)
                }
                Spacer()
                // RIGHT: Gizmo & viewer buttons
                VStack(spacing: 10) {
                    if !showLayerPreview && loadedSTLGeometry != nil {
                        overlayButton(
                            icon: "square.3.layers.3d",
                            label: showWireframe ? "Wire On" : "Wire Off",
                            active: showWireframe
                        ) { showWireframe.toggle() }

                        overlayButton(
                            icon: viewerColorMode.icon,
                            label: viewerColorMode.displayName,
                            active: viewerColorMode != .solid
                        ) { viewerColorMode = viewerColorMode.next }

                        overlayButton(
                            icon: "slider.vertical.3",
                            label: "Values",
                            active: !modelTransform.isIdentity
                        ) { showTransformPanel = true }

                        if isModelSelected {
                            Divider().frame(width: 36).padding(.vertical, 2)
                            overlayButton(icon: "move.3d",   label: "Move",   active: gizmoMode == .translate) { gizmoMode = .translate }
                            overlayButton(icon: "rotate.3d", label: "Rotate", active: gizmoMode == .rotate)    { gizmoMode = .rotate }
                            overlayButton(icon: "scale.3d",  label: "Scale",  active: gizmoMode == .scale)     { gizmoMode = .scale }
                        }
                    }

                    if case .done = state, !parsedLayers.isEmpty {
                        overlayButton(
                            icon: showLayerPreview ? "cube.transparent" : "square.3.layers.3d.slash",
                            label: showLayerPreview ? "Layers" : "Model",
                            active: showLayerPreview
                        ) { showLayerPreview.toggle() }
                    }
                }
                .padding(.trailing, 16)
            }
            .padding(.top, 60)
            Spacer()
        }
    }

    // MARK: - Transform bar

    @ViewBuilder
    private var transformBarContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(gizmoModeTitle)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                axisField("X", color: .red,   binding: currentXBinding)
                axisField("Y", color: .green, binding: currentYBinding)
                axisField("Z", color: .blue,  binding: currentZBinding)
                if !currentUnit.isEmpty {
                    Text(currentUnit).font(.caption2).foregroundStyle(.secondary).lineLimit(1).fixedSize()
                }
            }

            if gizmoMode == .scale {
                HStack(spacing: 6) {
                    Toggle("", isOn: $lockScale)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .scaleEffect(0.75, anchor: .leading)
                        .frame(width: 40)
                    Image(systemName: lockScale ? "lock.fill" : "lock.open")
                        .font(.caption2)
                        .foregroundStyle(lockScale ? Color.accentColor : Color.secondary)
                    Text("Lock aspect ratio")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let info = stlMeshInfo {
                Divider()
                dimensionRows(info: info)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func axisField(_ label: String, color: Color, binding: Binding<Float>) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            FloatField(value: binding, fmt: "%.2f")
                .font(.caption.monospacedDigit())
                .frame(width: 52)
        }
    }

    @ViewBuilder
    private func dimensionRows(info: STLMeshInfo) -> some View {
        let w = info.sizeMMX * modelTransform.scale.x
        let h = info.sizeMMZ * modelTransform.scale.y
        let d = info.sizeMMY * modelTransform.scale.z
        VStack(alignment: .leading, spacing: 2) {
            Text("Dimensions").font(.caption2.weight(.medium)).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                dimDot(Color.red,   value: w)
                dimDot(Color.green, value: h)
                dimDot(Color.blue,  value: d)
                Text("mm").font(.caption2).foregroundStyle(.secondary).lineLimit(1).fixedSize()
            }
        }
    }

    @ViewBuilder
    private func dimDot(_ color: Color, value: Float) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(String(format: "%.2f", value)).font(.caption2.monospacedDigit()).lineLimit(1).fixedSize()
        }
    }

    // MARK: - Transform bar helpers

    private var gizmoModeTitle: String {
        switch gizmoMode { case .translate: "Position"; case .rotate: "Rotation"; case .scale: "Scale" }
    }

    private var currentUnit: String {
        switch gizmoMode { case .translate: "mm"; case .rotate: "°"; case .scale: "" }
    }

    private var currentXBinding: Binding<Float> {
        switch gizmoMode {
        case .translate: Binding(get: { modelTransform.positionMM.x }, set: { modelTransform.positionMM.x = $0 })
        case .rotate:    Binding(get: { modelTransform.rotationDeg.x }, set: { modelTransform.rotationDeg.x = $0 })
        case .scale:     scaleXBinding
        }
    }
    private var currentYBinding: Binding<Float> {
        switch gizmoMode {
        case .translate: Binding(get: { modelTransform.positionMM.y }, set: { modelTransform.positionMM.y = $0 })
        case .rotate:    Binding(get: { modelTransform.rotationDeg.y }, set: { modelTransform.rotationDeg.y = $0 })
        case .scale:     scaleYBinding
        }
    }
    private var currentZBinding: Binding<Float> {
        switch gizmoMode {
        case .translate: Binding(get: { modelTransform.positionMM.z }, set: { modelTransform.positionMM.z = $0 })
        case .rotate:    Binding(get: { modelTransform.rotationDeg.z }, set: { modelTransform.rotationDeg.z = $0 })
        case .scale:     scaleZBinding
        }
    }

    private var scaleXBinding: Binding<Float> {
        Binding(get: { modelTransform.scale.x }) { v in
            guard v > 0 else { return }
            if lockScale, modelTransform.scale.x > 0 {
                let r = v / modelTransform.scale.x
                modelTransform.scale.x = v; modelTransform.scale.y *= r; modelTransform.scale.z *= r
            } else { modelTransform.scale.x = v }
        }
    }
    private var scaleYBinding: Binding<Float> {
        Binding(get: { modelTransform.scale.y }) { v in
            guard v > 0 else { return }
            if lockScale, modelTransform.scale.y > 0 {
                let r = v / modelTransform.scale.y
                modelTransform.scale.y = v; modelTransform.scale.x *= r; modelTransform.scale.z *= r
            } else { modelTransform.scale.y = v }
        }
    }
    private var scaleZBinding: Binding<Float> {
        Binding(get: { modelTransform.scale.z }) { v in
            guard v > 0 else { return }
            if lockScale, modelTransform.scale.z > 0 {
                let r = v / modelTransform.scale.z
                modelTransform.scale.z = v; modelTransform.scale.x *= r; modelTransform.scale.y *= r
            } else { modelTransform.scale.z = v }
        }
    }

    /// A labelled floating button for the viewer overlay.
    /// `active` adds an accent-colour border so the user can see the current state at a glance.
    @ViewBuilder
    private func overlayButton(icon: String, label: String, active: Bool, action: @escaping () -> Void) -> some View {
        VStack(spacing: 3) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.title3)
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(active ? Color.accentColor : Color.clear, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)

            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
        }
    }

    // MARK: - Layer slider

    private var layerSliderView: some View {
        VStack(spacing: 6) {
            Text("Layer \(currentLayerIndex + 1) of \(parsedLayers.count)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.black.opacity(0.55), in: Capsule())

            Slider(
                value: Binding(
                    get: { Double(currentLayerIndex) },
                    set: { currentLayerIndex = Int($0.rounded()) }
                ),
                in: 0...Double(max(0, parsedLayers.count - 1)),
                step: 1
            )
            .tint(.white)
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        VStack(spacing: 0) {
            // Drag handle + collapse/expand button
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isPanelExpanded.toggle()
                }
            } label: {
                VStack(spacing: 4) {
                    Capsule()
                        .fill(Color(.systemGray3))
                        .frame(width: 36, height: 4)
                    Image(systemName: isPanelExpanded ? "chevron.down" : "chevron.up")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if isPanelExpanded {
                expandedPanelContent
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                collapsedPanelContent
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 0)
        .shadow(color: .black.opacity(0.15), radius: 12, y: -4)
    }

    // Collapsed: one-line summary + slice button
    private var collapsedPanelContent: some View {
        HStack(spacing: 12) {
            statusIcon
                .scaleEffect(0.9)

            VStack(alignment: .leading, spacing: 1) {
                Text(loadedSTLName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(collapsedSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isBusy {
                Button(role: .destructive) {
                    if let h = activeHandle { slicer_cancel(h) }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    Task.detached(priority: .userInitiated) { await runSlice() }
                } label: {
                    Label("Slice", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isBusy)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
    }

    private var collapsedSubtitle: String {
        switch state {
        case .idle:
            return profileStore.selectedProfile?.name ?? "No printer selected"
        case .slicing(let phase, _):
            return phase
        case .done(_, let time, _):
            return time.map { "Done · \($0)" } ?? "Done"
        case .failed:
            return "Error — tap to expand"
        }
    }

    // Expanded: full controls
    private var expandedPanelContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                // File row
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loadedSTLName)
                            .font(.headline)
                        if let sp = sliceProfileStore.selectedProfile {
                            Text(sp.pickerSubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("No slice profile selected")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    Spacer()
                    Button {
                        showFilePicker = true
                    } label: {
                        Label("Load STL", systemImage: "folder")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isBusy)
                }

                Divider()

                // Printer profile row
                Button {
                    showProfilePicker = true
                } label: {
                    HStack {
                        Label(
                            profileStore.selectedProfile?.name ?? "No Printer Selected",
                            systemImage: "printer"
                        )
                        .font(.subheadline)
                        .foregroundStyle(profileStore.selectedProfile == nil ? .red : .primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(isBusy)

                // Slice profile row
                Button {
                    showSliceProfilePicker = true
                } label: {
                    HStack {
                        Label(
                            sliceProfileStore.selectedProfile?.name ?? "No Slice Profile Selected",
                            systemImage: "slider.horizontal.3"
                        )
                        .font(.subheadline)
                        .foregroundStyle(sliceProfileStore.selectedProfile == nil ? .red : .primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(isBusy)

                // Material profile row
                Button {
                    showMaterialProfilePicker = true
                } label: {
                    HStack {
                        Label(
                            materialProfileStore.selectedProfile?.name ?? "No Material Selected",
                            systemImage: "drop"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(isBusy)

                Divider()

                // Status row
                HStack(spacing: 12) {
                    statusIcon
                    Text(statusMessage)
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }

                if case .slicing(_, let p) = state {
                    ProgressView(value: p)
                        .animation(.linear(duration: 0.15), value: p)
                }

                Divider()

                // Action buttons
                actionButtons
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            // Safe area spacer
            Color.clear.frame(height: 20)
        }
    }

    // MARK: Sub-views

    @ViewBuilder
    private var statusIcon: some View {
        switch state {
        case .idle:
            Image(systemName: "circle").foregroundStyle(.secondary)
        case .slicing:
            ProgressView().scaleEffect(0.9)
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }

    private var statusMessage: String {
        switch state {
        case .idle:                 return "Ready to slice."
        case .slicing(let p, _):   return p
        case .done(let url, let time, let filament):
            var msg = "Done! \(url.lastPathComponent)"
            if let t = time { msg += "\nTime: \(t)" }
            if let f = filament { msg += "\nFilament: \(f) g" }
            return msg
        case .failed(let msg):     return "Error: \(msg)"
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task.detached(priority: .userInitiated) { await runSlice() }
            } label: {
                Label("Slice & Export G-code", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isBusy)

            if isBusy {
                Button(role: .destructive) {
                    if let h = activeHandle { slicer_cancel(h) }
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            if case .done(let url, _, _) = state {
                Button {
                    showShareSheet = true
                } label: {
                    Label("Share / Open in Files", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    // MARK: File import

    private func importSTL(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(url.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: url, to: dest)
            loadedSTLURL = dest
            loadedSTLName = url.lastPathComponent
            state = .idle
            // Reset state when a new model is loaded
            showLayerPreview = false
            parsedLayers = []
            modelTransform = .identity
            stlMeshInfo = nil
            isModelSelected = false
            gizmoMode = .translate
            parseSTLPreview(url: dest)
            Task.detached(priority: .background) {
                let info = try? parseSTLMeshInfo(url: dest)
                await MainActor.run { stlMeshInfo = info }
            }
        } catch {
            state = .failed(message: "Could not import STL: \(error.localizedDescription)")
            showErrorAlert = true
        }
    }

    private func parseSTLPreview(url: URL) {
        isParsingSTL = true
        let mode = viewerColorMode
        Task.detached(priority: .userInitiated) {
            let geo = try? parseSTL(url: url, colorMode: mode)
            await MainActor.run {
                loadedSTLGeometry = geo
                isParsingSTL = false
            }
        }
    }

    // MARK: Slicing

    private func setPhase(_ msg: String, progress: Double = 0) async {
        await MainActor.run { state = .slicing(phase: msg, progress: progress) }
    }

    private func runSlice() async {
        // 0. Require both profiles
        guard let printerProfile = await MainActor.run(body: { profileStore.selectedProfile }) else {
            await MainActor.run { showNoProfileAlert = true }
            return
        }
        guard let sliceProfile = await MainActor.run(body: { sliceProfileStore.selectedProfile }) else {
            await MainActor.run { showNoSliceProfileAlert = true }
            return
        }

        // 1. Resolve STL path
        let stlPath: String
        if let url = await MainActor.run(body: { loadedSTLURL }) {
            stlPath = url.path
        } else if let bundled = Bundle.main.path(forResource: "cube", ofType: "stl") {
            stlPath = bundled
        } else {
            await MainActor.run { state = .failed(message: "No STL file loaded") ; showErrorAlert = true }
            return
        }

        // 2. Output path in Documents
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let stem = URL(fileURLWithPath: stlPath).deletingPathExtension().lastPathComponent
        let outName = String(format: "%@_%.2fmm_%d.gcode",
                             stem, sliceProfile.layerHeight, sliceProfile.infillDensity)
        let gcodeURL = docs.appendingPathComponent(outName)

        // 3. Create slicer context
        await setPhase("Initialising slicer…")
        guard let handle = slicer_create() else {
            await MainActor.run { state = .failed(message: "slicer_create() returned nil") ; showErrorAlert = true }
            return
        }
        await MainActor.run { activeHandle = handle }
        defer {
            slicer_destroy(handle)
            Task { @MainActor in activeHandle = nil }
        }

        // 4. Apply printer profile
        await setPhase("Applying printer profile…")
        if !applyPrinterProfile(printerProfile, to: handle) {
            let msg = String(cString: slicer_last_error(handle))
            await MainActor.run { state = .failed(message: msg) ; showErrorAlert = true }
            return
        }

        // 5. Apply material profile (optional — falls back to bridge defaults if none selected)
        if let materialProfile = await MainActor.run(body: { materialProfileStore.selectedProfile }) {
            await setPhase("Applying material profile…")
            if !applyMaterialProfile(materialProfile, to: handle) {
                let msg = String(cString: slicer_last_error(handle))
                await MainActor.run { state = .failed(message: msg) ; showErrorAlert = true }
                return
            }
        }

        // 6. Apply slice profile
        await setPhase("Applying slice profile…")
        if !applySliceProfile(sliceProfile, to: handle) {
            let msg = String(cString: slicer_last_error(handle))
            await MainActor.run { state = .failed(message: msg) ; showErrorAlert = true }
            return
        }

        // 7. Load STL
        await setPhase("Loading \(URL(fileURLWithPath: stlPath).lastPathComponent)…")
        if slicer_load_stl(handle, stlPath) != 0 {
            let msg = String(cString: slicer_last_error(handle))
            await MainActor.run { state = .failed(message: msg) ; showErrorAlert = true }
            return
        }

        // 7a. Apply model transform (position/rotation/scale from the 3D viewer)
        let currentTransform = await MainActor.run(body: { modelTransform })
        var mt = SlicerModelTransform()
        mt.pos_x_mm  = currentTransform.positionMM.x
        mt.pos_z_mm  = currentTransform.positionMM.z
        mt.rot_x_deg = currentTransform.rotationDeg.x
        mt.rot_y_deg = currentTransform.rotationDeg.y
        mt.rot_z_deg = currentTransform.rotationDeg.z
        mt.scale_x   = currentTransform.scale.x
        mt.scale_y   = currentTransform.scale.y
        mt.scale_z   = currentTransform.scale.z
        if slicer_set_model_transform(handle, &mt) != 0 {
            let msg = String(cString: slicer_last_error(handle))
            await MainActor.run { state = .failed(message: msg) ; showErrorAlert = true }
            return
        }

        // 8. Slice with progress
        let lhStr = String(format: "%.2g", sliceProfile.layerHeight)
        await setPhase("Slicing at \(lhStr) mm / \(sliceProfile.infillDensity)% infill…")

        let relay = ProgressRelay()
        relay.handler = { pct in
            Task { @MainActor in
                if case .slicing(let phase, _) = state {
                    state = .slicing(phase: phase, progress: Double(pct) / 100.0)
                }
            }
        }
        let relayPtr = Unmanaged.passRetained(relay).toOpaque()

        // Run the blocking C++ call on a DispatchQueue thread so it does not
        // occupy a cooperative-thread-pool thread and starve UI/async updates.
        let sliceResult = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = slicer_slice_with_progress(
                    handle,
                    Float(sliceProfile.layerHeight),
                    Int32(sliceProfile.infillDensity),
                    { pct, ctx in
                        guard let ctx else { return }
                        Unmanaged<ProgressRelay>.fromOpaque(ctx).takeUnretainedValue().handler(pct)
                    },
                    relayPtr
                )
                continuation.resume(returning: result)
            }
        }
        Unmanaged<ProgressRelay>.fromOpaque(relayPtr).release()

        if sliceResult != 0 {
            let msg = String(cString: slicer_last_error(handle))
            await MainActor.run {
                if msg == "canceled" {
                    state = .idle
                } else {
                    state = .failed(message: msg)
                    showErrorAlert = true
                }
            }
            return
        }

        // 9. Export G-code
        await setPhase("Exporting G-code…", progress: 0.95)
        if slicer_export_gcode(handle, gcodeURL.path) != 0 {
            let msg = String(cString: slicer_last_error(handle))
            await MainActor.run { state = .failed(message: msg) ; showErrorAlert = true }
            return
        }

        // 10. Parse stats and layer preview data
        await setPhase("Parsing results…", progress: 0.99)
        let (printTime, filamentG) = parseGCodeStats(url: gcodeURL)
        let layers = parseGCode(url: gcodeURL)

        await MainActor.run {
            state = .done(gcodeURL: gcodeURL, printTime: printTime, filamentG: filamentG)
            parsedLayers = layers
            currentLayerIndex = max(0, layers.count - 1)
            showLayerPreview = false   // start on model view; user can switch via overlay button
        }
    }

    // MARK: G-code stats parsing

    private func parseGCodeStats(url: URL) -> (printTime: String?, filamentG: String?) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return (nil, nil) }
        var printTime: String?
        var filamentG: String?
        for line in text.components(separatedBy: "\n") {
            let s = line.trimmingCharacters(in: .whitespaces)
            if printTime == nil, s.hasPrefix("; estimated printing time (normal mode) =") {
                printTime = s.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces)
            }
            if filamentG == nil, s.hasPrefix("; filament used [g] =") {
                filamentG = s.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces)
            }
            if printTime != nil && filamentG != nil { break }
        }
        return (printTime, filamentG)
    }

    // MARK: Profiles → C bridge

    private func applySliceProfile(_ profile: SliceProfile, to handle: SlicerHandle) -> Bool {
        var cfg = SlicerSliceConfig()
        cfg.layer_height         = Float(profile.layerHeight)
        cfg.first_layer_height   = Float(profile.firstLayerHeight)
        cfg.wall_count           = Int32(profile.wallCount)
        cfg.horizontal_expansion = Float(profile.horizontalExpansion)
        cfg.top_layers           = Int32(profile.topLayers)
        cfg.bottom_layers        = Int32(profile.bottomLayers)
        cfg.top_thickness        = Float(profile.topThickness)
        cfg.bottom_thickness     = Float(profile.bottomThickness)
        cfg.infill_density       = Int32(profile.infillDensity)
        cfg.infill_pattern       = profile.infillPattern.bridgeInt
        cfg.print_speed          = Float(profile.printSpeed)
        cfg.infill_speed         = Float(profile.infillSpeed)
        cfg.travel_speed         = Float(profile.travelSpeed)
        cfg.first_layer_speed    = Float(profile.firstLayerSpeed)
        cfg.generate_support     = profile.generateSupport ? 1 : 0
        cfg.support_style        = profile.supportStyle.bridgeInt
        cfg.support_buildplate_only = profile.supportPlacement == .buildplateOnly ? 1 : 0
        cfg.support_overhang_angle  = Int32(profile.supportOverhangAngle)
        cfg.support_xy_spacing      = Float(profile.supportHorizontalExpansion)
        cfg.support_use_towers      = profile.supportUseTowers ? 1 : 0
        cfg.adhesion_type        = profile.adhesionType.bridgeInt
        cfg.brim_type            = profile.brimType.bridgeInt
        cfg.brim_width           = Float(profile.brimWidth)
        cfg.skirt_loops          = Int32(profile.skirtLoops)
        cfg.skirt_distance       = Float(profile.skirtDistance)
        cfg.raft_layers          = Int32(profile.raftLayers)
        return slicer_apply_slice_config(handle, &cfg) == 0
    }

    private func applyMaterialProfile(_ profile: MaterialProfile, to handle: SlicerHandle) -> Bool {
        var cfg = SlicerMaterialConfig()
        cfg.filament_diameter            = Float(profile.filamentDiameter)
        cfg.first_layer_temperature      = Int32(profile.firstLayerTemp)
        cfg.temperature                  = Int32(profile.otherLayersTemp)
        cfg.first_layer_bed_temperature  = Int32(profile.firstLayerBedTemp)
        cfg.bed_temperature              = Int32(profile.otherLayersBedTemp)
        cfg.extrusion_multiplier         = Float(profile.extrusionMultiplier)
        cfg.retract_length               = profile.retractionEnabled ? Float(profile.retractionLength) : 0
        cfg.retract_speed                = Float(profile.retractionSpeed)
        cfg.retract_restart_extra        = Float(profile.retractionRestartExtra)
        cfg.retract_lift                 = Float(profile.zHop)
        cfg.retract_before_travel        = Float(profile.minTravelForRetraction)
        cfg.cooling                      = profile.coolingEnabled ? 1 : 0
        cfg.min_fan_speed                = Int32(profile.minFanSpeed)
        cfg.max_fan_speed                = Int32(profile.maxFanSpeed)
        cfg.bridge_fan_speed             = Int32(profile.bridgeFanSpeed)
        cfg.disable_fan_first_layers     = Int32(profile.disableFanFirstLayers)
        cfg.fan_below_layer_time         = Int32(profile.fanBelowLayerTime)
        cfg.slowdown_below_layer_time    = Int32(profile.slowdownBelowLayerTime)
        cfg.min_print_speed              = Float(profile.minPrintSpeed)
        return slicer_apply_material_config(handle, &cfg) == 0
    }

    private func applyPrinterProfile(_ profile: PrinterProfile, to handle: SlicerHandle) -> Bool {
        let nozzle = Float(profile.extruders.first?.nozzleDiameter ?? 0.4)
        let filament = Float(profile.extruders.first?.compatibleMaterialDiameters.first ?? 1.75)

        return profile.startGCode.withCString { startPtr in
            profile.endGCode.withCString { endPtr in
                var cfg = SlicerPrinterConfig()
                cfg.bed_x = Float(profile.bedX)
                cfg.bed_y = Float(profile.bedY)
                cfg.bed_z = Float(profile.bedZ)
                cfg.origin_at_center = profile.originAtCenter ? 1 : 0
                cfg.heated_bed = profile.heatedBed ? 1 : 0
                cfg.gcode_flavor = profile.gcodeFlavor.bridgeInt
                cfg.start_gcode = startPtr
                cfg.end_gcode = endPtr
                cfg.printhead_x_min = Float(profile.printheadXMin)
                cfg.printhead_y_min = Float(profile.printheadYMin)
                cfg.printhead_x_max = Float(profile.printheadXMax)
                cfg.printhead_y_max = Float(profile.printheadYMax)
                cfg.gantry_height = Float(profile.gantryHeight)
                cfg.extruder_count = Int32(profile.numberOfExtruders)
                cfg.apply_extruder_offsets = profile.applyExtruderOffsetsToGCode ? 1 : 0
                cfg.nozzle_diameter = nozzle
                cfg.filament_diameter = filament
                return slicer_apply_printer_config(handle, &cfg) == 0
            }
        }
    }
}

// MARK: - Document Picker

struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let stlType = UTType(filenameExtension: "stl", conformingTo: .data) ?? UTType.data
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [stlType, UTType.data])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uvc: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController,
                            didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { onPick(url) }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(ProfileStore())
        .environmentObject(SliceProfileStore())
        .environmentObject(MaterialProfileStore())
}
