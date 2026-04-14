import Foundation

@MainActor
final class SliceProfileStore: ObservableObject {
    @Published var profiles: [SliceProfile] = []
    @Published var selectedProfileId: UUID?

    var selectedProfile: SliceProfile? {
        profiles.first { $0.id == selectedProfileId }
    }

    private var storeURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("slice_profiles.json")
    }

    // Bump when BuiltInSliceProfiles changes in a breaking way.
    private static let seedVersion = 1
    private static let seedVersionKey = "sliceProfileSeedVersion"

    // MARK: Load / Save

    func load() {
        let savedVersion = UserDefaults.standard.integer(forKey: Self.seedVersionKey)
        let versionMatch = savedVersion >= Self.seedVersion

        if versionMatch,
           let data = try? Data(contentsOf: storeURL),
           let decoded = try? JSONDecoder().decode([SliceProfile].self, from: data),
           !decoded.isEmpty {
            profiles = decoded
        } else {
            profiles = BuiltInSliceProfiles.all
            UserDefaults.standard.set(Self.seedVersion, forKey: Self.seedVersionKey)
            save()
        }

        if selectedProfileId == nil || !profiles.contains(where: { $0.id == selectedProfileId }) {
            selectedProfileId = profiles.first?.id
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }

    // MARK: Mutations

    func add(_ profile: SliceProfile) {
        profiles.append(profile)
        save()
    }

    func update(_ profile: SliceProfile) {
        guard let idx = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[idx] = profile
        save()
    }

    func delete(id: UUID) {
        guard profiles.count > 1 else { return }
        profiles.removeAll { $0.id == id }
        if selectedProfileId == id {
            selectedProfileId = profiles.first?.id
        }
        save()
    }

    func select(id: UUID) {
        selectedProfileId = id
    }
}
