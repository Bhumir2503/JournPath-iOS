import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

final class ItineraryService {
    private let db = Firestore.firestore()

    func saveItem(_ item: ItineraryItem) async throws -> String {
        let activityRef = db.collection("trips").document(item.tripId).collection("itineraryItems").document()

        let batch = db.batch()
        var updatedItem = item
        updatedItem.id = activityRef.documentID
        try batch.setData(from: updatedItem, forDocument: activityRef)
        try await batch.commit()
        
        return activityRef.documentID
    }

}
