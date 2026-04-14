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

    @State private var state: SliceState = .idle
    @State private var showShareSheet = false
    @State private var showFilePicker = false
    @State private var showErrorAlert = false
    @State private var showProfilePicker = false
    @State private var showNoProfileAlert = false

    /// URL of the STL that has been copied to the temp directory.
    @State private var loadedSTLURL: URL? = nil
    @State private var loadedSTLName: String = "None"

    /// SceneKit geometry for the 3D preview.
    @State private var loadedSTLGeometry: SCNGeometry? = nil
    @State private var isParsingSTL = false

    /// Retained while a slice is in progress; lets the cancel button reach slicer_cancel().
    @State private var activeHandle: SlicerHandle? = nil

    private let layerHeight: Float = 0.2
    private let infillPercent: Int32 = 20

    private var isBusy: Bool {
        if case .slicing = state { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 24) {
            headerSection
            Divider()
            modelSection
            statusSection
            Spacer()
            actionButtons
        }
        .padding(24)
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
    }

    // MARK: Sub-views

    private var headerSection: some View {
        VStack(spacing: 6) {
            Text("IosSlicer")
                .font(.largeTitle.bold())
            Text("On-device 3D Printing Slicer")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var modelSection: some View {
        GroupBox("Model") {
            VStack(spacing: 8) {
                // 3D viewer — always present so SceneKit's display link
                // stays attached to the window (avoids black-on-first-render).
                STLSceneView(geometry: loadedSTLGeometry)
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        if isParsingSTL {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6).opacity(0.7))
                                .overlay { ProgressView("Loading…") }
                        }
                    }

                // File info row
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loadedSTLName).font(.headline)
                        Text("Layer \(String(format: "%.1f", layerHeight)) mm · Infill \(infillPercent)%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                .padding(.vertical, 4)

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
                        .font(.caption)
                        .foregroundStyle(profileStore.selectedProfile == nil ? .red : .primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(isBusy)
            }
        }
    }

    private var statusSection: some View {
        GroupBox("Status") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    statusIcon
                    Text(statusMessage)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding(.vertical, 4)

                if case .slicing(_, let p) = state {
                    ProgressView(value: p)
                        .animation(.linear(duration: 0.15), value: p)
                }
            }
        }
    }

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
        // 0. Require a printer profile
        guard let profile = await MainActor.run(body: { profileStore.selectedProfile }) else {
            await MainActor.run { showNoProfileAlert = true }
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
        let outName = String(format: "%@_%.2fmm_%d.gcode", stem, layerHeight, infillPercent)
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
        if !applyPrinterProfile(profile, to: handle) {
            let msg = String(cString: slicer_last_error(handle))
            await MainActor.run { state = .failed(message: msg) ; showErrorAlert = true }
            return
        }

        // 5. Load STL
        await setPhase("Loading \(URL(fileURLWithPath: stlPath).lastPathComponent)…")
        if slicer_load_stl(handle, stlPath) != 0 {
            let msg = String(cString: slicer_last_error(handle))
            await MainActor.run { state = .failed(message: msg) ; showErrorAlert = true }
            return
        }

        // 6. Slice with progress
        await setPhase("Slicing at \(String(format: "%.1f", layerHeight)) mm / \(infillPercent)% infill…")

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
            handle, layerHeight, infillPercent,
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

        // 7. Export G-code
        await setPhase("Exporting G-code…", progress: 0.95)
        if slicer_export_gcode(handle, gcodeURL.path) != 0 {
            let msg = String(cString: slicer_last_error(handle))
            await MainActor.run { state = .failed(message: msg) ; showErrorAlert = true }
            return
        }

        await MainActor.run { state = .done(gcodeURL: gcodeURL) }
    }

    // MARK: Profile → C bridge

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
}
