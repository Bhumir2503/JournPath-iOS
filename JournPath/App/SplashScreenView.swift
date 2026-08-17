import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            Color(.black)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack {}.padding().padding().padding()
                Image("AppIcon")
                    .resizable()
                    .frame(width: 100, height: 100)
                Spacer()
            }

        }
    }
}

#Preview {
    SplashScreenView()
}
