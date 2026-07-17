import FirebaseFirestore
import Foundation
import Observation
import SwiftUI

@Observable
final class TripListManager {
    var trips: [TripInfo] = []
    var hasFetchedTrips: Bool = false
    var searchText: String = ""

    private var listener: ListenerRegistration?

    var filteredTrips: [TripInfo] {
        if searchText.isEmpty { return trips }
        return trips.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    /// "Today" as UTC midnight — must match the same anchor used for
    /// trip.startDate/endDate, or every comparison below will be off by
    /// up to a day depending on the device's timezone offset from UTC.
    private var todayUTCMidnight: Date {
        Date().utcMidnight
    }

    var currentTrips: [TripInfo] {
        let today = todayUTCMidnight
        return
            filteredTrips
            .filter { today >= $0.startDate && today <= $0.endDate }
            .sorted { $0.startDate < $1.startDate }
    }

    var upcomingTrips: [TripInfo] {
        let today = todayUTCMidnight
        return
            filteredTrips
            .filter { $0.startDate > today }
            .sorted { $0.startDate < $1.startDate }  // soonest upcoming first
    }

    var pastTrips: [TripInfo] {
        let today = todayUTCMidnight
        return
            filteredTrips
            .filter { $0.endDate < today }
            .sorted { $0.endDate > $1.endDate }  // most recently ended first
    }

    // MARK: - Lifecycle
    func startListening(userId: String) {
        guard listener == nil else { return }
        AppLogger.managers.info("[TripListManager.swift] Listening to the Trip Sub-Collection in userId: \(userId)")

        listener = Firestore.firestore()
            .collection("users")
            .document(userId)
            .collection("trips")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    AppLogger.managers.error("[TripListManager.swift] Listener error: \(error.localizedDescription)")
                    self.hasFetchedTrips = true
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.trips = []
                    self.hasFetchedTrips = true
                    return
                }

                let newTrips = documents.compactMap { doc in
                    do {
                        return try doc.data(as: TripInfo.self)
                    } catch {
                        AppLogger.managers.error("[TripListManager.swift] Decode failed for \(doc.documentID): \(error.localizedDescription)")
                        return nil
                    }
                }

                if self.hasFetchedTrips {
                    withAnimation(.easeInOut(duration: 0.3)) { self.trips = newTrips }
                } else {
                    self.trips = newTrips  // first load: no animation
                    self.hasFetchedTrips = true
                }
                self.hasFetchedTrips = true
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    deinit {
        stopListening()
    }
}
