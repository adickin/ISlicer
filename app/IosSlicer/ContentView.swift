import SwiftUI
import UIKit
import UniformTypeIdentifiers
import SceneKit

// MARK: - State

enum SliceState {
    case idle
    case slicing(phase: String, progress: Double)
    case done(gcodeURL: URL)
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

    /// URL of the STL that has been copied to the temp directory.
    @State private var loadedSTLURL: URL? = nil
    @State private var loadedSTLName: String = "None"

    /// SceneKit geometry for the 3D preview.
    @State private var loadedSTLGeometry: SCNGeometry? = nil
    @State private var isParsingSTL = false

    /// Retained while a slice is in progress; lets the cancel button reach slicer_cancel().
    @State private var activeHandle: SlicerHandle? = nil

    private var isBusy: Bool {
        if case .slicing = state { return true }
        return false
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-screen 3D viewer
            STLSceneView(
                geometry: loadedSTLGeometry,
                bedX: profileStore.selectedProfile?.bedX ?? 220,
                bedY: profileStore.selectedProfile?.bedY ?? 220
            )
                .ignoresSafeArea()
                .overlay {
                    if isParsingSTL {
                        Color(.systemGray6).opacity(0.7)
                            .ignoresSafeArea()
                            .overlay { ProgressView("Loading…") }
                    }
                }

            // Bottom panel
            bottomPanel
        }
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: $showFilePicker) {
            DocumentPickerView { url in
                importSTL(from: url)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if case .done(let url) = state {
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
        case .done:
            return "Done"
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
        case .done(let url):       return "Done! G-code saved:\n\(url.lastPathComponent)"
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

            if case .done(let url) = state {
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
            parseSTLPreview(url: dest)
        } catch {
            state = .failed(message: "Could not import STL: \(error.localizedDescription)")
            showErrorAlert = true
        }
    }

    private func parseSTLPreview(url: URL) {
        // Don't nil out geometry — keep the old model visible while the new one parses.
        isParsingSTL = true
        Task.detached(priority: .userInitiated) {
            let geo = try? parseSTL(url: url)
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

        // 7. Slice with progress
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

        let sliceResult = slicer_slice_with_progress(
            handle,
            Float(sliceProfile.layerHeight),
            Int32(sliceProfile.infillDensity),
            { pct, ctx in
                guard let ctx else { return }
                Unmanaged<ProgressRelay>.fromOpaque(ctx).takeUnretainedValue().handler(pct)
            },
            relayPtr
        )
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

        // 8. Export G-code
        await setPhase("Exporting G-code…", progress: 0.95)
        if slicer_export_gcode(handle, gcodeURL.path) != 0 {
            let msg = String(cString: slicer_last_error(handle))
            await MainActor.run { state = .failed(message: msg) ; showErrorAlert = true }
            return
        }

        await MainActor.run { state = .done(gcodeURL: gcodeURL) }
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

        // withCString keeps the C strings alive for the duration of the nested closures.
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
