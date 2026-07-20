//
//  Trip.swift
//  MyJourney
//

import FirebaseAuth
import FirebaseFirestore
import SwiftUI

enum TripRole: String, Codable {
    case owner = "owner"
    case passenger = "passenger"
}

enum TripTier: Int, Codable {
    case free = 0
    case premium = 1
}

struct Trip: Identifiable, Codable, Hashable {
    @DocumentID var id: String?

    // Access Control
    var inviteToken: String

    // Basic Info
    var name: String
    var imageURL: String
    var imageColor: String
    var imageBlurHash: String
    var imageAuthor: String

    // Timestamps
    var startDate: Date
    var endDate: Date

    // MetaData
    var createdAt: Date
    var updatedAt: Date?

    // Premium Flag
    var tier: TripTier

    var dynamicTextColor: Color {
        Color.accessibleTextColor(for: imageColor)
    }

    static func createNew(
        name: String,
        startDate: Date,
        endDate: Date,
        imageURL: String,
        imageColor: String,
        imageBlurHash: String,
        imageAuthor: String
    ) -> [String: Any] {
        return [
            "name": name,
            "startDate": startDate.utcMidnight,
            "endDate": endDate.utcMidnight,
            "imageURL": imageURL,
            "imageColor": imageColor,
            "imageBlurHash": imageBlurHash,
            "imageAuthor": imageAuthor
        ]
    }
}
