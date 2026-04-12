import SwiftUI

// MARK: - State

enum SliceState {
    case idle
    case slicing(phase: String)
    case done(gcodeURL: URL)
    case failed(message: String)
}

// MARK: - ContentView

struct ContentView: View {
    @State private var state: SliceState = .idle
    @State private var showShareSheet = false

    // Hardcoded settings for the v1 prototype
    private let layerHeight: Float = 0.2      // mm
    private let infillPercent: Int32 = 20     // %

    var body: some View {
        VStack(spacing: 32) {
            // ── Header ───────────────────────────────────────────
            VStack(spacing: 6) {
                Text("IosSlicer")
                    .font(.largeTitle.bold())
                Text("On-device 3D Printing Slicer")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // ── Model info ───────────────────────────────────────
            GroupBox("Model") {
                HStack {
                    Image(systemName: "cube.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading) {
                        Text("cube.stl").font(.headline)
                        Text("20 × 20 × 20 mm · Layer \(String(format: "%.1f", layerHeight)) mm · Infill \(infillPercent)%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            // ── Status ───────────────────────────────────────────
            statusView

            Spacer()

            // ── Actions ──────────────────────────────────────────
            VStack(spacing: 12) {
                sliceButton
                if case .done(let url) = state {
                    shareButton(url: url)
                }
            }
        }
        .padding(24)
        .sheet(isPresented: $showShareSheet) {
            if case .done(let url) = state {
                ShareSheetView(items: [url])
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: Sub-views

    @ViewBuilder
    private var statusView: some View {
        GroupBox("Status") {
            HStack(spacing: 12) {
                statusIcon
                Text(statusMessage)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.vertical, 4)
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
        case .idle:              return "Ready to slice."
        case .slicing(let p):   return p
        case .done(let url):    return "Done! G-code saved:\n\(url.lastPathComponent)"
        case .failed(let msg):  return "Error: \(msg)"
        }
    }

    @ViewBuilder
    private var sliceButton: some View {
        let busy: Bool = {
            if case .slicing = state { return true }
            return false
        }()

        Button {
            Task.detached(priority: .userInitiated) { await runSlice() }
        } label: {
            Label("Slice & Export G-code", systemImage: "slider.horizontal.3")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(busy)
    }

    private func shareButton(url: URL) -> some View {
        Button {
            showShareSheet = true
        } label: {
            Label("Share / Open in Files", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    // MARK: Slicing logic

    private func setPhase(_ msg: String) async {
        await MainActor.run { state = .slicing(phase: msg) }
    }

    private func runSlice() async {
        // 1. Find bundled STL
        guard let stlPath = Bundle.main.path(forResource: "cube", ofType: "stl") else {
            await MainActor.run { state = .failed(message: "cube.stl not found in app bundle") }
            return
        }

        // 2. Resolve output path
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outName = String(format: "cube_%.2fmm_%d.gcode", layerHeight, infillPercent)
        let gcodeURL = docs.appendingPathComponent(outName)

        // 3. Create slicer context
        await setPhase("Initialising slicer…")
        guard let handle = slicer_create() else {
            await MainActor.run { state = .failed(message: "slicer_create() returned nil") }
            return
        }
        defer { slicer_destroy(handle) }

        // 4. Load STL
        await setPhase("Loading \(URL(fileURLWithPath: stlPath).lastPathComponent)…")
        let loadResult = slicer_load_stl(handle, stlPath)
        if loadResult != 0 {
            let msg = String(cString: slicer_last_error(handle))
            await MainActor.run { state = .failed(message: "load_stl: \(msg)") }
            return
        }

        // 5. Slice
        await setPhase("Slicing at \(String(format: "%.1f", layerHeight)) mm layer height, \(infillPercent)% infill…")
        let sliceResult = slicer_slice(handle, layerHeight, Int32(infillPercent))
        if sliceResult != 0 {
            let msg = String(cString: slicer_last_error(handle))
            await MainActor.run { state = .failed(message: "slice: \(msg)") }
            return
        }

        // 6. Export G-code
        await setPhase("Exporting G-code…")
        let exportResult = slicer_export_gcode(handle, gcodeURL.path)
        if exportResult != 0 {
            let msg = String(cString: slicer_last_error(handle))
            await MainActor.run { state = .failed(message: "export_gcode: \(msg)") }
            return
        }

        await MainActor.run { state = .done(gcodeURL: gcodeURL) }
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
}
