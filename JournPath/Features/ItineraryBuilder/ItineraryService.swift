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

    func deleteItem(tripId: String, itemId: String) async throws {
        // First delete any expenses associated with this activity
        try await ExpenseService().deleteForActivity(activityId: itemId, in: tripId)
        
        // Then delete the activity itself
        try await db.collection("trips").document(tripId).collection("itineraryItems").document(itemId).delete()
    }
}
