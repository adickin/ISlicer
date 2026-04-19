import SwiftUI

struct SplashView: View {
    var body: some View {
        Color.black
            .ignoresSafeArea()
            .overlay(
                Image("LaunchImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
            )
    }
}
