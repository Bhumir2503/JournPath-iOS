import Foundation
import SwiftUI

@Observable
final class CreateTripViewModel {
    private let tripService = TripService()

    // MARK: - Form State
    var name: String = ""
    var startDate: Date? = nil
    var endDate: Date? = nil
    var isProcessing: Bool = false
    var errorMessage: String? = nil

    // MARK: - Cover Image
    var coverImage: CoverImage? = nil

    /// Owned here rather than in the form so the empty-state background can
    /// open the picker too.
    var isShowingImagePicker: Bool = false

    /// Neutral tone used before a photo is chosen.
    static let placeholderColor = "#8E8E93"

    var dynamicTextColor: Color {
        Color.accessibleTextColor(for: coverImage?.color ?? Self.placeholderColor)
    }

    // MARK: - Validation

    var hasValidDates: Bool {
        guard let start = startDate, let end = endDate else { return false }
        return start <= end
    }

    var isValid: Bool {
        !name.trimmed.isBlank && hasValidDates && coverImage != nil
    }

    /// Drives the hint under the create button so the disabled state is explained.
    var validationHint: String? {
        if name.trimmed.isBlank { return "Give your trip a name" }
        if !hasValidDates { return "Pick your travel dates" }
        if coverImage == nil { return "Choose a cover photo" }
        return nil
    }

    // MARK: - Actions

    func createTrip() async -> String? {
        guard let start = startDate, let end = endDate, let cover = coverImage else { return nil }

        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            return try await tripService.create(
                name: name.trimmed,
                startDate: start,
                endDate: end,
                coverImage: cover
            )
        } catch {
            AppLogger.viewModels.error("Error creating trip: \(error)")
            errorMessage = "Couldn't create your trip. Please try again."
            return nil
        }
    }
}
