import Foundation

@MainActor
final class ProfileStore: ObservableObject {
    @Published var profiles: [PrinterProfile] = []
    @Published var selectedProfileId: UUID?

    var selectedProfile: PrinterProfile? {
        profiles.first { $0.id == selectedProfileId }
    }

    private var storeURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("printer_profiles.json")
    }

    // Bump this any time BuiltInProfiles changes in a way that would break
    // existing saved profiles (e.g. gcode syntax fix, renamed fields).
    // On mismatch the saved file is discarded and re-seeded from BuiltInProfiles.all.
    private static let seedVersion = 2
    private static let seedVersionKey = "profileSeedVersion"

    // MARK: Load / Save

    func load() {
        let savedVersion = UserDefaults.standard.integer(forKey: Self.seedVersionKey)
        let versionMatch = savedVersion >= Self.seedVersion

        if versionMatch,
           let data = try? Data(contentsOf: storeURL),
           let decoded = try? JSONDecoder().decode([PrinterProfile].self, from: data),
           !decoded.isEmpty {
            profiles = decoded
        } else {
            profiles = BuiltInProfiles.all
            UserDefaults.standard.set(Self.seedVersion, forKey: Self.seedVersionKey)
            save()
        }

        if mergeInMissingBuiltIns() {
            save()
        }

        if selectedProfileId == nil || !profiles.contains(where: { $0.id == selectedProfileId }) {
            selectedProfileId = profiles.first?.id
        }
    }

    // Adds any BuiltInProfiles template not already present, so a user who
    // already has a saved printer_profiles.json (and may have customized
    // their existing profiles) still picks up newly-added built-ins on
    // their next app update instead of only new installs seeing them.
    // Matches by builtInKey when set; older saved profiles predate that
    // field, so those fall back to matching by name to avoid duplicating
    // a built-in the user already has.
    @discardableResult
    private func mergeInMissingBuiltIns() -> Bool {
        var added = false
        for template in BuiltInProfiles.all {
            let alreadyPresent = profiles.contains { existing in
                if let key = template.builtInKey {
                    if existing.builtInKey == key { return true }
                }
                return existing.builtInKey == nil && existing.name == template.name
            }
            if !alreadyPresent {
                profiles.append(template)
                added = true
            }
        }
        return added
    }

    func save() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }

    // MARK: Mutations

    func add(_ profile: PrinterProfile) {
        var p = profile
        normalizeExtruders(&p)
        profiles.append(p)
        save()
    }

    func update(_ profile: PrinterProfile) {
        guard let idx = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        var p = profile
        normalizeExtruders(&p)
        profiles[idx] = p
        save()
    }

    func delete(id: UUID) {
        guard profiles.count > 1 else { return }   // always keep at least one
        profiles.removeAll { $0.id == id }
        if selectedProfileId == id {
            selectedProfileId = profiles.first?.id
        }
        save()
    }

    func select(id: UUID) {
        selectedProfileId = id
    }

    // MARK: Helpers

    // Ensures extruders array length == numberOfExtruders.
    private func normalizeExtruders(_ p: inout PrinterProfile) {
        let target = max(1, p.numberOfExtruders)
        while p.extruders.count < target { p.extruders.append(ExtruderProfile()) }
        if p.extruders.count > target { p.extruders = Array(p.extruders.prefix(target)) }
    }
}
