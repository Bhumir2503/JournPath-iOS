import Kingfisher
import SwiftUI
import UnifiedBlurHash

struct TripDashboardHeader: View {
    let trip: Trip
    let geometry: GeometryProxy
    let scrollOffset: CGFloat

    @State private var showingCredit = false

    private var headerHeight: CGFloat {
        (geometry.size.height * 0.45) + (scrollOffset < 0 ? abs(scrollOffset) : 0)
    }

    private var parallaxOffset: CGFloat {
        scrollOffset > 0 ? min(scrollOffset, geometry.size.height * 0.25) : 0
    }

    var body: some View {
        KFImage(trip.coverImage.regularURL)
            .placeholder { placeholder }
            .resizable()
            .scaledToFill()
            .frame(width: geometry.size.width, height: headerHeight)
            .offset(y: parallaxOffset)
            .clipped()
            .overlay(alignment: .bottomTrailing) { creditButton }
    }

    // MARK: - Placeholder

    @ViewBuilder
    private var placeholder: some View {
        if let blurImage = Image(blurHash: trip.coverImage.blurHash) {
            blurImage
                .resizable()
                .scaledToFill()
        } else {
            // Blur hash decoding can fail; the average colour is a safe floor.
            trip.coverImage.backgroundColor
        }
    }

    // MARK: - Credit

    private var creditButton: some View {
        Button {
            showingCredit = true
        } label: {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 20))
                .symbolRenderingMode(.palette)
                // White glyph on a dark scrim reads over any photo without
                // needing to know the image's brightness.
                .foregroundStyle(.white, .black.opacity(0.35))
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                // Pads the tap target out to 44pt without growing the glyph.
                .frame(width: 44, height: 44, alignment: .center)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Photo credit")
        .padding(.trailing, 4)
        .padding(.bottom, 4)
        .popover(isPresented: $showingCredit) {
            creditCard
                .presentationCompactAdaptation(.popover)
        }
    }

    private var creditCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Photo Credit")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if let profileURL = trip.coverImage.profileURL {
                Link(destination: profileURL) {
                    Label(trip.coverImage.photographerName, systemImage: "person.crop.circle")
                        .font(.subheadline.weight(.semibold))
                }
            } else {
                Label(trip.coverImage.photographerName, systemImage: "person.crop.circle")
                    .font(.subheadline.weight(.semibold))
            }

            Link(destination: URL(string: "https://unsplash.com/?utm_source=journpath&utm_medium=referral")!) {
                Label("View on Unsplash", systemImage: "arrow.up.right.square")
                    .font(.subheadline)
            }
        }
        .padding(16)
        .frame(minWidth: 220, alignment: .leading)
    }
}