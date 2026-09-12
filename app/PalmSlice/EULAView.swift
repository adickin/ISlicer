import SwiftUI

/// Shown once, on first launch, before the app can be used. Not dismissible
/// except by tapping Accept — see PalmSliceApp for the gating logic.
struct EULAView: View {
    let onAccept: () -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Beta Software")
                        .font(.title2.weight(.semibold))

                    Text("PalmSlice is beta software under active development. Please read before continuing.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    bulletList

                    Text("If you do not agree to these terms, do not use this app.")
                        .font(.subheadline.weight(.medium))
                        .padding(.top, 8)
                }
                .padding(20)
                .padding(.bottom, 80)
            }
            .navigationTitle("Before You Continue")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button(action: onAccept) {
                        Text("I Understand & Accept")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(role: .destructive) {
                        // No way to use the app without accepting, so declining exits it outright.
                        exit(0)
                    } label: {
                        Text("Decline & Quit")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .interactiveDismissDisabled()
    }

    private var bulletList: some View {
        VStack(alignment: .leading, spacing: 12) {
            bullet("This is beta software. Bugs, crashes, and inaccurate slicing results may occur.")
            bullet("You use PalmSlice, and print any G-code it produces, entirely at your own risk.")
            bullet("The developer(s) are not responsible or liable for any damages, injury, or loss — including damage to your printer, materials, or property — arising from the use of this software or the files it produces.")
            bullet("Always supervise your 3D printer during operation, and review sliced output before printing.")
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\u{2022}")
                .font(.subheadline.weight(.bold))
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    EULAView(onAccept: {})
}
