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
    private let apiBaseURL = URL(string: "https://api.journpath.com")!
    
    @discardableResult
    func create(name: String, startDate: Date, endDate: Date, imageURL: String, imageColor: String, imageBlurHash: String, imageAuthor: String) async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw TripServiceError.notAuthenticated
        }

        // Tokens required by the `gate` middleware (Auth + App Check)
        let idToken = try await user.getIDToken()
        let appCheckToken = try await AppCheck.appCheck().token(forcingRefresh: false)

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

        var request = URLRequest(url: apiBaseURL.appendingPathComponent("createTrip"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue(appCheckToken.token, forHTTPHeaderField: "X-Firebase-AppCheck")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw TripServiceError.invalidResponse
        }

        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]

        guard (200..<300).contains(http.statusCode) else {
            let message = json?["message"] as? String ?? json?["error"] as? String
            throw TripServiceError.serverError(status: http.statusCode, message: message)
        }

        guard let tripId = json?["tripId"] as? String else {
            throw TripServiceError.invalidResponse
        }

        return tripId
    }

    func rename(tripId: String, newName: String) async throws {
        _ = try AuthUtils.requireUserId()
        let updates: [String: Any] = [
            "name": newName,
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        try await db.collection("trips").document(tripId).updateData(updates)
    }

    func updateDates(tripId: String, startDate: Date, endDate: Date) async throws {
        _ = try AuthUtils.requireUserId()
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
        _ = try AuthUtils.requireUserId()
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
}

// MARK: - User Management
extension TripService {
    func regenerateInviteToken(tripId: String) async throws {
        _ = try AuthUtils.requireUserId()
        let updates: [String: Any] = [
            "inviteToken": InviteTokenUtil.generate(),
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        try await db.collection("trips").document(tripId).updateData(updates)
    }
}

// MARK: - Listeners
extension TripService {
    func listenToTripCollection(userId: String, completion: @escaping ([Trip]?, Error?) -> Void) -> () -> Void {
        let listener = db.collection("trips")
            .whereField("participants", arrayContains: userId)
            .whereField("isDeleted", isEqualTo: false)
            .order(by: "startDate", descending: false)
            .addSnapshotListener { snapshot, error in

                if let error = error {
                    AppLogger.database.error("[TripService.swift] Error listening to trip collection: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }

                let trips = snapshot?.documents.compactMap { doc -> Trip? in
                    do {
                        return try doc.data(as: Trip.self)
                    } catch {
                        AppLogger.database.error("[TripService.swift] Failed to decode trip \(doc.documentID): \(error.localizedDescription)")
                        return nil
                    }
                }
                completion(trips, nil)
            }

        return { listener.remove() }
    }

    func listenToTripDocument(tripId: String, completion: @escaping (Trip?, Error?) -> Void) -> () -> Void {
        let listener = db.collection("trips").document(tripId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    AppLogger.database.error("[TripService.swift] Error listening to trip document: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }
                let trip = try? snapshot?.data(as: Trip.self)
                completion(trip, nil)
            }

        return { listener.remove() }
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
