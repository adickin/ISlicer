import SwiftUI

/// A bordered, monospaced TextEditor with a label and a copy button.
/// Used for start/end G-code fields throughout the profile editor.
struct GCodeEditorView: View {
    let label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    UIPasteboard.general.string = text
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption2)
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }

            TextEditor(text: $text)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )
        }
    }
}
