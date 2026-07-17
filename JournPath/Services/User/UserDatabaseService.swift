//
//  UserDatabaseService.swift
//  MyJourney
//

import FirebaseAuth
import FirebaseFirestore
import Foundation

class UserDatabaseService {
    private let db = Firestore.firestore()
    
    func leaveTrip(tripId: String) async throws {
        let uid = try AuthUtils.requireUserId()
        try await db.collection("users").document(uid).collection("trips").document(tripId).delete()
    }
}
