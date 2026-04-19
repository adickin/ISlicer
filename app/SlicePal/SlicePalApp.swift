import SwiftUI

@main
struct SlicePalApp: App {
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var sliceProfileStore = SliceProfileStore()
    @StateObject private var materialProfileStore = MaterialProfileStore()

    init() {
        copySampleSTLsToDocuments()
    }

    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(profileStore)
                    .environmentObject(sliceProfileStore)
                    .environmentObject(materialProfileStore)
                    .task {
                        profileStore.load()
                        sliceProfileStore.load()
                        materialProfileStore.load()
                    }
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.easeOut(duration: 0.3)) { showSplash = false }
            }
        }
    }
}

/// Copy bundled sample STL files into the app's Documents folder so they
/// appear in the Files app under On My iPhone → SlicePal.
private func copySampleSTLsToDocuments() {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let samples = Bundle.main.urls(forResourcesWithExtension: "stl", subdirectory: nil) ?? []
    for src in samples {
        let dest = docs.appendingPathComponent(src.lastPathComponent)
        guard !FileManager.default.fileExists(atPath: dest.path) else { continue }
        try? FileManager.default.copyItem(at: src, to: dest)
    }
}
