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

    func create(name: String, startDate: Date, endDate: Date, imageURL: String, imageColor: String, imageBlurHash: String, imageAuthor: String) async throws(APIError) -> String {
        let formatter = ISO8601DateFormatter()

        let payload: [String: Any] = [
            "trip": [
                "name": name,
                "startDate": formatter.string(from: startDate),
                "endDate": formatter.string(from: endDate),
                "imageURL": imageURL,
                "imageColor": imageColor,
                "imageBlurHash": imageBlurHash,
                "imageAuthor": imageAuthor,
            ]
        ]

        let result = try await APIClient.shared.post("/trip/create", body: payload)
        guard let tripId = result["tripId"] as? String else {
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
        // change to UTC
        let start = startDate.utcMidnight
        let end = endDate.utcMidnight

        let updates: [String: Any] = [
            "startDate": start,
            "endDate": end,
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        try await db.collection("trips").document(tripId).updateData(updates)
    }

    func updateBackground(tripId: String, imageBlurHash: String, imageURL: String, imageColor: String, imageAuthor: String) async throws {
        let updates: [String: Any] = [
            "imageBlurHash": imageBlurHash,
            "imageURL": imageURL,
            "imageColor": imageColor,
            "imageAuthor": imageAuthor,
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        try await db.collection("trips").document(tripId).updateData(updates)
    }

    func makePremium(tripId: String, initialEndDate: String) async throws {
        _ = try AuthUtils.requireUserId()
        let updates: [String: Any] = [
            "initialEndDate": initialEndDate,
            "isPremium": true,
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        try await db.collection("trips").document(tripId).updateData(updates)
    }

    func leaveTrip(tripId: String) async throws {
        let uid = try AuthUtils.requireUserId()
        try await db.collection("users").document(uid).collection("trips").document(tripId).delete()
    }
}

// MARK: - User Management
extension TripService {
    func regenerateInviteToken(tripId: String) async throws {
        try await APIClient.shared.post("/trip/regenerateInviteToken", body: ["tripId": tripId])
    }
}

// MARK: - Errors
enum TripServiceError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case serverError(status: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to do this."
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .serverError(let status, let message):
            return message ?? "Request failed with status \(status)."
        }
    }
}
