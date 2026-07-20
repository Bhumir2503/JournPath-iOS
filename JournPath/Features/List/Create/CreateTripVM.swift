import Foundation
import SwiftUI

@Observable
final class CreateTripViewModel {
    private let tripService = TripService()

    // MARK: - Form State
    var name: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date().addingTimeInterval(24 * 60 * 60 * 7)
    var isProcessing: Bool = false

    // MARK: - Image State
    var backgroundImageUrl: String? = nil
    var backgroundColor: String? = nil
    var backgroundBlurHash: String? = nil
    var backgroundAuthor: String? = nil
    private var localImages: [UnsplashImage] = []

    var dynamicTextColor: Color {
        Color.accessibleTextColor(for: backgroundColor ?? "#8c4040")
    }

    var isValid: Bool {
        !name.trimmed.isBlank && startDate <= endDate
    }

    func loadLocalImages() {
        guard let url = Bundle.main.url(forResource: "PredefinedBackgrounds", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else {
            print("Error: PredefinedBackgrounds.json not found.")
            return
        }

        do {
            self.localImages = try JSONDecoder().decode([UnsplashImage].self, from: data)
            selectRandomImage()
        } catch {
            print("Failed to decode local images: \(error)")
        }
    }

    func selectRandomImage() {
        guard let randomImage = localImages.randomElement() else { return }

        self.backgroundImageUrl = randomImage.urls.regular
        self.backgroundColor = randomImage.color
        self.backgroundBlurHash = randomImage.blurHash
        self.backgroundAuthor = randomImage.user.name
    }

    func createTrip() async -> String? {
        isProcessing = true
        defer { isProcessing = false }

        do {

            let dayFormatter: DateFormatter = {
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                df.calendar = Calendar(identifier: .gregorian)
                df.timeZone = .current  // extract the day the user *saw* in the picker
                return df
            }()
            let payload: [String: Any] = [
                "trip": [
                    "name": name,
                    "startDate": dayFormatter.string(from: startDate),
                    "endDate": dayFormatter.string(from: endDate),
                    "imageURL": backgroundImageUrl ?? "https://images.unsplash.com/photo-1501258338179-b25f87809429?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w4MjcxOTF8MHwxfHNlYXJjaHwxMXx8Z3JhbmQlMjBjYW55b258ZW58MHx8fHwxNzgxNzUzMTIxfDA&ixlib=rb-4.1.0&q=80&w=1080",
                    "imageColor": backgroundColor ?? "#8c4040",
                    "imageBlurHash": backgroundBlurHash ?? "LWE2|dXTIU%hcukXw]oz5Sxa%1Mx",
                    "imageAuthor": backgroundAuthor ?? "Unknown",
                ]
            ]
            let result = try await APIClient.shared.post("/trip/create", body: payload)
            AppLogger.viewModels.info("Trip created: \(result)")
            return (result["result"] as? [String: Any])?["tripId"] as? String
        } catch {
            AppLogger.viewModels.error("Error creating trip: \(error)")
        }
        return nil
    }
}
