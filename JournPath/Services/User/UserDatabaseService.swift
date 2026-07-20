//
//  UserDatabaseService.swift
//  MyJourney
//

import FirebaseAuth
import FirebaseFirestore
import Foundation

class UserDatabaseService {
    private let db = Firestore.firestore()

    func updateProfile(displayName: String?, photoURL: String?) async throws {
        let uid = try AuthUtils.requireUserId()
        try await db.collection("users").document(uid).updateData([
            "displayName": displayName ?? "",
            "photoURL": photoURL ?? ""
        ])
    }
    
    func leaveTrip(tripId: String) async throws {
        let uid = try AuthUtils.requireUserId()
        try await db.collection("users").document(uid).collection("trips").document(tripId).delete()
    }
}
