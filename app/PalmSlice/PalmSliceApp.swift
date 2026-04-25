import SwiftUI

@main
struct PalmSliceApp: App {
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var sliceProfileStore = SliceProfileStore()
    @StateObject private var materialProfileStore = MaterialProfileStore()

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

