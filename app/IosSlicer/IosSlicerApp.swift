import SwiftUI

@main
struct IosSlicerApp: App {
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var sliceProfileStore = SliceProfileStore()

    init() {
        copySampleSTLsToDocuments()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(profileStore)
                .environmentObject(sliceProfileStore)
                .task {
                    profileStore.load()
                    sliceProfileStore.load()
                }
        }
    }
}

/// Copy bundled sample STL files into the app's Documents folder so they
/// appear in the Files app under On My iPhone → IosSlicer.
private func copySampleSTLsToDocuments() {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let samples = Bundle.main.urls(forResourcesWithExtension: "stl", subdirectory: nil) ?? []
    for src in samples {
        let dest = docs.appendingPathComponent(src.lastPathComponent)
        guard !FileManager.default.fileExists(atPath: dest.path) else { continue }
        try? FileManager.default.copyItem(at: src, to: dest)
    }
}
