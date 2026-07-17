import Combine
import Foundation
import SwiftUI

@Observable
final class ItineraryManager {
    // MARK: - State
    var items: [ItineraryItem] = []
    var isLoading: Bool = true
    var errorMessage: String? = nil

    // MARK: - Dependencies
    private let tripId: String
    @ObservationIgnored private let itineraryService = ItineraryService()

    private var cancelListener: (() -> Void)?

    // MARK: - Initialization
    init(tripId: String) {
        self.tripId = tripId
    }

    deinit {
        stopListening()
    }

    // MARK: - Lifecycle Management
    func startListening() {
        guard !tripId.isEmpty else { return }
        guard cancelListener == nil else { return }

        AppLogger.managers.info("[ItineraryManager.swift] Started listening to itinerary for trip: \(tripId)")

        cancelListener = itineraryService.listenToItinerary(tripId: tripId) { [weak self] items, error in
            self?.isLoading = false
            if let error = error {
                self?.errorMessage = "Failed to load itinerary."
                AppLogger.database.error("[ItineraryManager.swift] Error fetching itinerary: \(error)")
            } else {
                self?.items = items ?? []
                self?.errorMessage = nil
            }
        }
    }

    func stopListening() {
        if cancelListener != nil {
            AppLogger.managers.info("[ItineraryManager.swift] Stopped listening to itinerary for trip: \(tripId)")
            cancelListener?()
            cancelListener = nil
        }
    }
}
