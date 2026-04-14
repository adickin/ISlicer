import SwiftUI

struct SliceProfileEditorView: View {
    enum Mode { case add, edit }

    let mode: Mode
    @EnvironmentObject var sliceProfileStore: SliceProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft: SliceProfile
    @State private var showHelp = false

    init(mode: Mode, profile: SliceProfile = SliceProfile()) {
        self.mode = mode
        _draft = State(initialValue: profile)
    }

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                layersSection
                wallsSection
                topBottomSection
                infillSection
                speedSection
                supportSection
                adhesionSection
                helpButtonSection
            }
            .navigationTitle(mode == .add ? "New Slice Profile" : "Edit Slice Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save", action: save)
            )
            .sheet(isPresented: $showHelp) {
                SliceProfileHelpView()
            }
        }
    }

    private var helpButtonSection: some View {
        Section {
            Button {
                showHelp = true
            } label: {
                Label("Setting Descriptions", systemImage: "questionmark.circle")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section("Name") {
            TextField("Profile name", text: $draft.name)
        }
    }

    private var layersSection: some View {
        Section("Layers") {
            LabeledContent("Layer Height (mm)") {
                TextField("0.2", value: $draft.layerHeight, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("First Layer Height (mm)") {
                TextField("0.2", value: $draft.firstLayerHeight, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var wallsSection: some View {
        Section("Walls") {
            Stepper("Wall Count: \(draft.wallCount)", value: $draft.wallCount, in: 1...20)
            LabeledContent("Horizontal Expansion (mm)") {
                TextField("0", value: $draft.horizontalExpansion, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var topBottomSection: some View {
        Section("Top / Bottom") {
            Stepper("Top Layers: \(draft.topLayers)", value: $draft.topLayers, in: 0...20)
            Stepper("Bottom Layers: \(draft.bottomLayers)", value: $draft.bottomLayers, in: 0...20)
            LabeledContent("Min Top Thickness (mm)") {
                TextField("0", value: $draft.topThickness, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Min Bottom Thickness (mm)") {
                TextField("0", value: $draft.bottomThickness, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var infillSection: some View {
        Section("Infill") {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Density")
                    Spacer()
                    Text("\(draft.infillDensity)%")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: Binding(
                    get: { Double(draft.infillDensity) },
                    set: { draft.infillDensity = Int($0.rounded()) }
                ), in: 0...100, step: 1)
            }
            Picker("Pattern", selection: $draft.infillPattern) {
                ForEach(InfillPattern.allCases) { pattern in
                    Text(pattern.rawValue).tag(pattern)
                }
            }
        }
    }

    private var speedSection: some View {
        Section("Speed (mm/s)") {
            LabeledContent("Print (Perimeter)") {
                TextField("60", value: $draft.printSpeed, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Infill") {
                TextField("80", value: $draft.infillSpeed, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Travel") {
                TextField("120", value: $draft.travelSpeed, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("First Layer") {
                TextField("30", value: $draft.firstLayerSpeed, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    @ViewBuilder
    private var supportSection: some View {
        Section("Support") {
            Toggle("Generate Support", isOn: $draft.generateSupport)

            if draft.generateSupport {
                Picker("Style", selection: $draft.supportStyle) {
                    ForEach(SupportStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                Picker("Placement", selection: $draft.supportPlacement) {
                    ForEach(SupportPlacement.allCases) { placement in
                        Text(placement.rawValue).tag(placement)
                    }
                }
                Stepper("Overhang Angle: \(draft.supportOverhangAngle)°",
                        value: $draft.supportOverhangAngle, in: 0...90)
                LabeledContent("Horizontal Expansion (mm)") {
                    TextField("0.7", value: $draft.supportHorizontalExpansion, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                Toggle("Use Support Towers", isOn: $draft.supportUseTowers)
            }
        }
    }

    @ViewBuilder
    private var adhesionSection: some View {
        Section("Build Plate Adhesion") {
            Picker("Type", selection: $draft.adhesionType) {
                ForEach(AdhesionType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))

            switch draft.adhesionType {
            case .none:
                EmptyView()

            case .skirt:
                Stepper("Skirt Loops: \(draft.skirtLoops)", value: $draft.skirtLoops, in: 1...10)
                LabeledContent("Skirt Distance (mm)") {
                    TextField("6", value: $draft.skirtDistance, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }

            case .brim:
                Picker("Brim Placement", selection: $draft.brimType) {
                    ForEach(BrimType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                LabeledContent("Brim Width (mm)") {
                    TextField("8", value: $draft.brimWidth, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }

            case .raft:
                Stepper("Raft Layers: \(draft.raftLayers)", value: $draft.raftLayers, in: 1...10)
            }
        }
    }

    // MARK: - Save

    private func save() {
        if mode == .add {
            sliceProfileStore.add(draft)
        } else {
            sliceProfileStore.update(draft)
        }
        dismiss()
    }
}

// MARK: - Help Sheet

private struct SliceProfileHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(helpSections) { section in
                Section(section.title) {
                    ForEach(section.entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.name)
                                .font(.headline)
                            Text(entry.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Setting Descriptions")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

private struct HelpSection: Identifiable {
    let id = UUID()
    let title: String
    let entries: [HelpEntry]
}

private struct HelpEntry: Identifiable {
    let id = UUID()
    let name: String
    let description: String
}

private let helpSections: [HelpSection] = [
    HelpSection(title: "Layers", entries: [
        HelpEntry(name: "Layer Height",
                  description: "Thickness of each printed layer in mm. Lower values give a smoother surface and finer detail but take much longer to print. Common values: 0.1 mm (fine), 0.2 mm (standard), 0.3 mm (draft)."),
        HelpEntry(name: "First Layer Height",
                  description: "Thickness of only the very first layer. A slightly thicker first layer (e.g. 0.25 mm when printing at 0.2 mm) helps the plastic squish onto the bed and improves adhesion. Usually set equal to or slightly above the main layer height."),
    ]),
    HelpSection(title: "Walls", entries: [
        HelpEntry(name: "Wall Count",
                  description: "Number of perimeter loops printed around the outside of the model. More walls means a stronger, more watertight shell. 2–3 walls is typical; increase to 4+ for parts that need to hold stress or be watertight."),
        HelpEntry(name: "Horizontal Expansion",
                  description: "Shrinks or expands the model outline in XY. Positive values make the print slightly larger (compensates for material shrinkage); negative values make it smaller (useful for tight-tolerance holes or press fits). 0 means no adjustment."),
    ]),
    HelpSection(title: "Top / Bottom", entries: [
        HelpEntry(name: "Top Layers",
                  description: "Number of solid layers printed on the top surface. More layers produce a smoother, more solid top; fewer layers can show the infill pattern through the top. 4–6 is typical for 0.2 mm layer height."),
        HelpEntry(name: "Bottom Layers",
                  description: "Number of solid layers printed on the bottom (first layers on the bed). Similar tradeoff to top layers. Usually the same count as top layers."),
        HelpEntry(name: "Min Top Thickness",
                  description: "Alternative way to specify top solid layers: the slicer will add enough layers so the total top thickness is at least this many mm, regardless of layer height. Set to 0 to use the layer count only."),
        HelpEntry(name: "Min Bottom Thickness",
                  description: "Same as Min Top Thickness but for the bottom. Set to 0 to use the layer count only."),
    ]),
    HelpSection(title: "Infill", entries: [
        HelpEntry(name: "Density",
                  description: "How much of the interior is filled with plastic, as a percentage. 0% is hollow, 100% is completely solid. 15–20% is common for decorative prints; 40%+ for parts that need structural strength."),
        HelpEntry(name: "Pattern",
                  description: "The geometry of the infill structure inside the model. Gyroid is strong in all directions and prints well at high speeds. Grid is simple and fast. Honeycomb is efficient. Adaptive Cubic gets denser near surfaces automatically. Lightning is ultra-fast with minimal material but weak — good for display models only."),
    ]),
    HelpSection(title: "Speed", entries: [
        HelpEntry(name: "Print Speed (Perimeter)",
                  description: "How fast the nozzle moves while printing the outer walls. This has the biggest impact on surface quality — slower produces better results. 40–60 mm/s is typical; go lower for high-detail prints."),
        HelpEntry(name: "Infill Speed",
                  description: "How fast the nozzle moves while printing the interior infill. Since infill is hidden inside the model, it can go faster than the perimeter without affecting visible quality. 60–100 mm/s is common."),
        HelpEntry(name: "Travel Speed",
                  description: "How fast the nozzle moves when not extruding plastic (moving between features). Faster travel reduces stringing and print time. 120–150 mm/s is typical; direct-drive printers can go faster than Bowden."),
        HelpEntry(name: "First Layer Speed",
                  description: "Speed for the entire first layer only. Printing slowly on the first layer gives the plastic more time to adhere to the bed. 20–30 mm/s is common regardless of other speed settings."),
    ]),
    HelpSection(title: "Support", entries: [
        HelpEntry(name: "Generate Support",
                  description: "When on, the slicer automatically adds support structures under overhanging sections of the model that would otherwise print in mid-air. Supports are removed after printing and usually leave a rough surface where they touched."),
        HelpEntry(name: "Style",
                  description: "Normal (Snug) generates a tight grid structure — strong but can be hard to remove. Tree (Organic) grows branching columns up from the bed — easier to remove and touches the model less, but takes longer to generate and can be less stable on large overhangs."),
        HelpEntry(name: "Placement",
                  description: "Everywhere allows supports to grow from any part of the model surface. Touching Build Plate Only restricts supports to columns that start from the bed — cleaner result but some overhangs may go unsupported."),
        HelpEntry(name: "Overhang Angle",
                  description: "The steepness of an overhang (measured from vertical) that triggers support generation. 50° is the standard — most FDM printers can bridge shallower angles without support. Lower this value to add more support; raise it to add less."),
        HelpEntry(name: "Horizontal Expansion",
                  description: "Gap in mm between the edge of the model and the edge of the support structure in XY. A larger gap makes supports easier to remove but leaves the overhang slightly unsupported near the edges. 0.5–1.0 mm is typical."),
        HelpEntry(name: "Use Support Towers",
                  description: "Adds a sheath (outer wall) around support columns to make them more rigid and less likely to topple on tall, narrow supports. Useful for tall models with small overhangs far from the bed."),
    ]),
    HelpSection(title: "Build Plate Adhesion", entries: [
        HelpEntry(name: "None",
                  description: "No adhesion structure. Use when the model has a large flat bottom that adheres well on its own, or when you're printing on a surface that grips well (e.g. PEI with PLA)."),
        HelpEntry(name: "Skirt",
                  description: "One or more loops printed around — but not touching — the model before the print starts. Primes the nozzle and lets you confirm the first layer height looks correct before the actual print begins. Does not help with adhesion."),
        HelpEntry(name: "Brim",
                  description: "A flat ring of extra material printed directly attached to the first layer of the model, extending outward. Greatly increases the contact area with the bed, reducing warping on materials like ABS or PETG and on models with small footprints."),
        HelpEntry(name: "Raft",
                  description: "A thick multi-layer platform printed first, with the actual model on top of it. The raft is peeled off after printing. Most useful for models with very small first-layer footprints, or when printing on a bed that has trouble with first-layer adhesion."),
        HelpEntry(name: "Brim Width",
                  description: "How far the brim extends outward from the model edge in mm. Wider brim = more adhesion = harder to remove. 5–8 mm is typical; increase for tall narrow models or warpy materials."),
        HelpEntry(name: "Skirt Loops",
                  description: "How many loops the skirt makes around the model. 1–2 is usually enough to prime the nozzle."),
        HelpEntry(name: "Skirt Distance",
                  description: "How far the skirt sits from the model edge in mm. Keep it small (2–6 mm) so the nozzle is primed close to where printing starts."),
        HelpEntry(name: "Raft Layers",
                  description: "How many layers thick the raft is. More layers make a more stable raft but are harder to remove. 2–3 is typical."),
    ]),
]
