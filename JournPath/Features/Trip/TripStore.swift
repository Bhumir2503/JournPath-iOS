import FirebaseAuth
import FirebaseFirestore
import Foundation

@Observable
final class TripStore {
    // MARK: - Dependencies
    let tripId: String
    var state: LoadState<Trip> = .idle

    // MARK: - State
    var trip: Trip? = nil

    // MARK: - Computed Vars
    var name: String {
        return trip?.name ?? ""
    }

    var tier: TripTier {
        return trip?.tier ?? .free
    }

    var inviteToken: String {
        return trip?.inviteToken ?? ""
    }

    var shareURL: URL? {
        let path = "https://journpath.com/invite/trip/\(tripId)"
        var components = URLComponents(string: path)
        components?.queryItems = [
            URLQueryItem(name: "token", value: inviteToken)
        ]
        return components?.url
    }

    var dateRangeString: String {
        guard let trip = trip else { return "" }
        return trip.dateRangeTextViaInterval
    }

    // MARK: - Firestore Listeners
    private var tripListener: ListenerRegistration?

    // MARK: - Initialization
    init(tripId: String) {
        self.tripId = tripId
    }

    deinit {
        stop()
    }

    func start() {
        guard !tripId.isEmpty, tripListener == nil else { return }

        AppLogger.managers.info("[TripStore.swift] Started listening for trip document: \(tripId)")

        tripListener = Firestore.firestore()
            .collection("trips")
            .document(tripId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    AppLogger.managers.error("[TripStore.swift] Trip listener error: \(error.localizedDescription)")
                    self.state = .failed(AnyAppError("Failed to Load Trip", "Please try again later."))
                    return
                }

                guard let doc = snapshot else { return }

                guard doc.exists else {
                    self.trip = nil
                    self.state = .failed(AnyAppError("Failed to Load Trip", "This trip does not exist or you no longer have access to it."))
                    return
                }

                do {
                    self.trip = try doc.data(as: Trip.self)
                    self.state = .loaded(self.trip!)
                } catch {
                    AppLogger.managers.error("[TripStore.swift] Trip decode failed: \(error.localizedDescription)")
                    self.state = .failed(AnyAppError("Failed to Load Trip", "Please try again later."))
                }
            }
    }

    func stop() {
        AppLogger.managers.info("[TripStore.swift] Stopped listening for trip document: \(tripId)")
        tripListener?.remove()
        tripListener = nil
    }
}
