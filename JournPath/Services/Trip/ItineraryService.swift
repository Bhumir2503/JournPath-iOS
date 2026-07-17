import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

final class ItineraryService {
    private let db = Firestore.firestore()

    func saveItem(_ item: ItineraryItem) async throws {
        let docRef = db.collection("trips").document(item.tripId).collection("itinerary").document()
        try docRef.setData(from: item)
    }

    func listenToItinerary(tripId: String, completion: @escaping ([ItineraryItem]?, Error?) -> Void) -> () -> Void {
        let listener = db.collection("trips")
            .document(tripId)
            .collection("itinerary")
            .order(by: "startTime")
            .order(by: "endTime")
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }

                guard let documents = querySnapshot?.documents else {
                    completion([], nil)
                    return
                }

                let items: [ItineraryItem] = documents.compactMap { document in
                    do {
                        return try document.data(as: ItineraryItem.self)
                    } catch {
                        print("Error decoding itinerary item \(document.documentID): \(error)")
                        return nil
                    }
                }

                completion(items, nil)
            }

        return { listener.remove() }
    }

    func observeItems(forTripId tripId: String) -> AnyPublisher<[ItineraryItem], Error> {
        let subject = PassthroughSubject<[ItineraryItem], Error>()

        let listener = db.collection("trips")
            .document(tripId)
            .collection("itinerary")
            .order(by: "startTime")
            .order(by: "endTime")
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }

                guard let documents = querySnapshot?.documents else {
                    subject.send([])
                    return
                }

                let items: [ItineraryItem] = documents.compactMap { document in
                    do {
                        return try document.data(as: ItineraryItem.self)
                    } catch {
                        print("Error decoding itinerary item \(document.documentID): \(error)")
                        return nil
                    }
                }

                subject.send(items)
            }

        return
            subject
            .handleEvents(receiveCancel: {
                listener.remove()
            })
            .eraseToAnyPublisher()
    }

}
