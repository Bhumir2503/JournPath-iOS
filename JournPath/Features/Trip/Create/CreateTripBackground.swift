import Foundation
import Kingfisher
import SwiftUI
import UnifiedBlurHash

extension CreateTripView {

    struct Background: View {
        @Environment(CreateTripViewModel.self) private var vm

        var body: some View {
            ZStack {
                (vm.coverImage?.backgroundColor ?? Color(hex: CreateTripViewModel.placeholderColor))
                    .ignoresSafeArea()

                GeometryReader { geo in
                    if let cover = vm.coverImage, let url = cover.regularURL {
                        remoteImage(cover: cover, url: url, size: geo.size)
                    } else {
                        emptyState(size: geo.size)
                    }
                }
            }
        }

        // MARK: - Selected image

        private func remoteImage(cover: CoverImage, url: URL, size: CGSize) -> some View {
            KFImage(url)
                .placeholder { blurHashPlaceholder(cover.blurHash) }
                .fade(duration: 0.2)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height * 0.50)
                .clipped()
                .mask(fadeMask)
                .overlay(darkTopOverlay)
        }

        /// Shown only while the chosen photo downloads - we have a real blur hash
        /// at this point, so it resolves into the actual image.
        private func blurHashPlaceholder(_ hash: String) -> some View {
            ZStack {
                if let blurImage = Image(blurHash: hash) {
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

        // MARK: - No image chosen yet

        /// Deliberately not a spinner. Nothing is loading here - the user simply
        /// hasn't picked a photo, and a cover is required to create the trip.
        private func emptyState(size: CGSize) -> some View {
            VStack(spacing: 10) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 60, weight: .light))
            }
            .foregroundStyle(vm.dynamicTextColor.opacity(0.75))
            .frame(width: size.width, height: size.height * 0.50)
            .contentShape(Rectangle())
            .onTapGesture { vm.isShowingImagePicker = true }
            .mask(fadeMask)
            .overlay(darkTopOverlay)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Add a cover photo, required")
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
