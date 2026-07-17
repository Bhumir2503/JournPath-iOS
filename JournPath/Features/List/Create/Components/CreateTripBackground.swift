import Foundation
import Kingfisher
import SwiftUI
import UnifiedBlurHash

extension CreateTripView {

    struct Background: View {
        @Environment(CreateTripViewModel.self) private var vm
        private let fallbackBlurHash = "LWE2|dXTIU%hcukXw]oz5Sxa%1Mx"

        var body: some View {
            Group {
                Color(hex: vm.backgroundColor ?? "#8c4040")
                    .ignoresSafeArea()

                GeometryReader { geo in
                    if let urlString = vm.backgroundImageUrl, let url = URL(string: urlString) {
                        remoteImage(url: url, size: geo.size)
                    } else {
                        emptyStateImage
                    }
                }
            }
        }

        private func remoteImage(url: URL, size: CGSize) -> some View {
            KFImage(url)
                .placeholder { imagePlaceholder }
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height * 0.50)
                .clipped()
                .mask(fadeMask)  // Used extracted mask
                .overlay(darkTopOverlay)  // Used extracted overlay
        }

        @ViewBuilder
        private var emptyStateImage: some View {
            ZStack {
                if let blurImage = Image(blurHash: vm.backgroundBlurHash ?? fallbackBlurHash) {
                    blurImage
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(white: 0.2)
                }
                ProgressView()
                    .tint(vm.dynamicTextColor)
            }
        }

        @ViewBuilder
        private var imagePlaceholder: some View {
            ZStack {
                if let blurImage = Image(blurHash: vm.backgroundBlurHash ?? fallbackBlurHash) {
                    blurImage
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(white: 0.2)
                }
                ProgressView()
                    .tint(vm.dynamicTextColor)
            }
        }

        // MARK: - Gradients & Styling

        private var fadeMask: some View {
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0.5),
                    .init(color: .clear, location: 1.0),
                ],
                startPoint: .top, endPoint: .bottom
            )
        }

        private var darkTopOverlay: some View {
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.5), location: 0),
                    .init(color: .clear, location: 0.4),
                ],
                startPoint: .top, endPoint: .bottom
            )
        }
    }
}
