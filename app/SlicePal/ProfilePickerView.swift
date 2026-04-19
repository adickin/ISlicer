import SwiftUI

struct ProfilePickerView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var showAddEditor = false
    @State private var profileToEdit: PrinterProfile? = nil

    var body: some View {
        NavigationStack {
            List {
                ForEach(profileStore.profiles) { profile in
                    ProfileRowView(
                        profile: profile,
                        isSelected: profileStore.selectedProfileId == profile.id,
                        onSelect: { profileStore.select(id: profile.id) },
                        onOpen:   { profileToEdit = profile },
                        onDelete: { profileStore.delete(id: profile.id) },
                        canDelete: profileStore.profiles.count > 1
                    )
                }
            }
            .navigationTitle("Printer Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Done") { dismiss() },
                trailing: Button(action: { showAddEditor = true }) {
                    Image(systemName: "plus")
                }
            )
            .sheet(isPresented: $showAddEditor) {
                PrinterProfileEditorView(mode: .add)
            }
            .sheet(item: $profileToEdit) { profile in
                PrinterProfileEditorView(mode: .edit, profile: profile)
            }
        }
    }
}

private struct ProfileRowView: View {
    let profile: PrinterProfile
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onDelete: () -> Void
    let canDelete: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Tap circle to make this the active printer
            Button(action: onSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)

            // Tap name/details area to open editor
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .foregroundStyle(.primary)
                        .fontWeight(isSelected ? .semibold : .regular)
                    Text(bedSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            .disabled(!canDelete)
        }
    }

    private var bedSummary: String {
        String(format: "%.0f × %.0f × %.0f mm · %@",
               profile.bedX, profile.bedY, profile.bedZ, profile.gcodeFlavor.rawValue)
    }
}
