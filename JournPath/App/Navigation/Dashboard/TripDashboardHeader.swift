import Kingfisher
import SwiftUI
import UnifiedBlurHash

struct TripDashboardHeader: View {
    let trip: Trip
    let geometry: GeometryProxy
    let scrollOffset: CGFloat

    var body: some View {
        KFImage(URL(string: trip.coverImage.regular))
            .placeholder {
                if let blurImage = Image(blurHash: trip.coverImage.blurHash) {
                    blurImage.resizable().scaledToFill()
                }
            }
            .resizable()
            .scaledToFill()
            .frame(
                width: geometry.size.width,
                height: (geometry.size.height * 0.45)
                    + (scrollOffset < 0 ? abs(scrollOffset) : 0)
            )
            .offset(y: scrollOffset > 0 ? min(scrollOffset, geometry.size.height * 0.25) : 0)
            .clipped()
    }
}
