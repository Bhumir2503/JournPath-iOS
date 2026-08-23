import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

final class ItineraryService {
    private let db = Firestore.firestore()

    func saveItem(_ item: ItineraryItem) async throws {
        let activityRef = db.collection("trips").document(item.tripId).collection("itineraryItems").document()

        let batch = db.batch()
        try batch.setData(from: item, forDocument: activityRef)
        try await batch.commit()
    }

}
