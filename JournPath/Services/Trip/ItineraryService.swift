import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

final class ItineraryService {
    private let db = Firestore.firestore()

    func saveItem(_ item: ItineraryItem, costInfo: CostInfo) async throws {
        let activityRef = db.collection("trips").document(item.tripId).collection("itineraryItems").document()

        let batch = db.batch()
        try batch.setData(from: item, forDocument: activityRef)
        
        // Only attach an expense if an amount > 0 was entered.
        if let amount = costInfo.totalAmount, amount > 0 {
            let expense = try Expense(from: costInfo, activityId: activityRef.documentID, title: item.activity!.name, createdBy: item.createdBy)
            try batch.setData(from: expense, forDocument: db.collection("trips").document(item.tripId).collection("expenses").document())
        }
        
        try await batch.commit()
    }



}
