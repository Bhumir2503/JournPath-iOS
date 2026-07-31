//
//  CoverImage.swift
//  MyJourney
//

import SwiftUI

/// A trip's cover photo, denormalised at selection time so nothing that renders
/// a trip ever needs to hit the Unsplash API again. Stored as a map on the trip
/// document and mirrored onto the user's trip card.
struct CoverImage: Codable, Hashable {

    /// Unsplash photo id. Needed for the download ping and to detect re-selection.
    var id: String

    var regular: String
    var small: String

    var color: String
    var blurHash: String

    /// Attribution is required wherever the photo is displayed, so it travels with it.
    var photographerName: String
    var photographerProfile: String

    /// Reserved for when users can upload their own covers.
    var source: String
}

// MARK: - Conversion

extension CoverImage {
    init(_ image: UnsplashImage) {
        self.init(
            id: image.id,
            regular: image.urls.regular,
            small: image.urls.small,
            color: image.color,
            blurHash: image.blurHash,
            photographerName: image.user.name,
            photographerProfile: image.user.profile,
            source: "unsplash"
        )
    }
}

// MARK: - Presentation

extension CoverImage {
    var regularURL: URL? { URL(string: regular) }
    var smallURL: URL? { URL(string: small) }
    var profileURL: URL? { URL(string: photographerProfile) }

    var textColor: Color { Color.accessibleTextColor(for: color) }
    var backgroundColor: Color { Color(hex: color) }

    var attributionText: String { "Photo by \(photographerName) on Unsplash" }
}

// MARK: - API payload

extension CoverImage {
    /// Shape sent to `/trip/create` and `/trip/updateBackground`.
    var payload: [String: Any] {
        [
            "id": id,
            "regular": regular,
            "small": small,
            "color": color,
            "blurHash": blurHash,
            "photographerName": photographerName,
            "photographerProfile": photographerProfile,
            "source": source,
        ]
    }
}
