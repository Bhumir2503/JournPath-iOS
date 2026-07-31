//
//  TripServices.swift
//  MyJourney
//

import FirebaseAppCheck
import FirebaseAuth
import FirebaseFirestore
import Foundation

final class TripService {

    private let db = Firestore.firestore()

    func create(
        name: String,
        startDate: Date,
        endDate: Date,
        coverImage: CoverImage
    ) async throws(APIError) -> String {

        let payload: [String: Any] = [
            "trip": [
                "name": name,
                // Match updateDates: trips are day-granular, stored at UTC midnight.
                "startDate": startDate.utcMidnight.iso8601,
                "endDate": endDate.utcMidnight.iso8601,
                "coverImage": coverImage.payload,
            ]
        ]

        let response = try await APIClient.shared.post("/trip/create", body: payload)

        // The API wraps every success in `{ "result": ... }`.
        guard
            let result = response["result"] as? [String: Any],
            let tripId = result["tripId"] as? String
        else {
            throw APIError.invalidResponse
        }
        return tripId
    }

    func rename(tripId: String, newName: String) async throws {
        let updates: [String: Any] = [
            "name": newName,
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        try await db.collection("trips").document(tripId).updateData(updates)
    }

    func updateDates(tripId: String, startDate: Date, endDate: Date) async throws {
        let updates: [String: Any] = [
            "startDate": startDate.utcMidnight,
            "endDate": endDate.utcMidnight,
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        try await db.collection("trips").document(tripId).updateData(updates)
    }

    func updateCoverImage(tripId: String, coverImage: CoverImage) async throws {
        let updates: [String: Any] = [
            "coverImage": coverImage.payload,
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        try await db.collection("trips").document(tripId).updateData(updates)
    }

    func makePremium(tripId: String, initialEndDate: String) async throws {
        _ = try AuthUtils.requireUserId()
        let updates: [String: Any] = [
            "initialEndDate": initialEndDate,
            "tier": TripTier.premium.rawValue,
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        try await db.collection("trips").document(tripId).updateData(updates)
    }

    func leave(tripId: String) async throws(APIError) {
        let response = try await APIClient.shared.post("/trip/leave", body: ["tripId": tripId])

        guard response["result"] as? [String: Any] != nil else {
            throw APIError.invalidResponse
        }
    }
}

// MARK: - User Management
extension TripService {
    func regenerateInviteToken(tripId: String) async throws {
        try await APIClient.shared.post("/trip/regenerateInviteToken", body: ["tripId": tripId])
    }
}
