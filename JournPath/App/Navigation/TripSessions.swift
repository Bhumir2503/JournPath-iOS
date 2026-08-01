final class TripSession {
    let tripId: String
    var trip: TripStore
    var participants: ParticipantStore
    var storage: StorageStore

    init(tripId: String) {
        self.tripId = tripId
        self.trip = TripStore(tripId: tripId)
        self.participants = ParticipantStore(tripId: tripId)
        self.storage = StorageStore(tripId: tripId)
    }

    deinit {
        stop()
    }

    func start() {
        trip.start()
        participants.start()
    }

    func stop() {
        trip.stop()
        participants.stop()
        storage.stop()
    }
}
