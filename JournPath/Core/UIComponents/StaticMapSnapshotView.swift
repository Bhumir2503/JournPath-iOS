import SwiftUI
import MapKit

struct StaticMapSnapshotView: View {
    let coordinate: CLLocationCoordinate2D
    let height: CGFloat
    let spanMeters: CLLocationDistance

    init(coordinate: CLLocationCoordinate2D, height: CGFloat, spanMeters: CLLocationDistance = 1000) {
        self.coordinate = coordinate
        self.height = height
        self.spanMeters = spanMeters
    }

    @State private var snapshotImage: UIImage?
    @State private var isLoading = false
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image = snapshotImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: proxy.size.width, height: height)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(UIColor.secondarySystemBackground))
                        .frame(width: proxy.size.width, height: height)
                        .overlay {
                            if isLoading {
                                ProgressView()
                            }
                        }
                }

                // Marker
                Image(systemName: "mappin.circle.fill")
                    .font(.title)
                    .foregroundColor(.red)
                    .background(Circle().fill(Color.white).padding(4))
            }
            .task(id: proxy.size) {
                await generateSnapshot(size: CGSize(width: proxy.size.width, height: height))
            }
        }
        .frame(height: height)
    }

    private func generateSnapshot(size: CGSize) async {
        guard size.width > 0 && size.height > 0 else { return }
        isLoading = true

        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: spanMeters, longitudinalMeters: spanMeters)
        options.size = size
        options.scale = displayScale

        let snapshotter = MKMapSnapshotter(options: options)
        
        do {
            let snapshot = try await snapshotter.start()
            await MainActor.run {
                self.snapshotImage = snapshot.image
                self.isLoading = false
            }
        } catch {
            print("Map snapshot error: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}
