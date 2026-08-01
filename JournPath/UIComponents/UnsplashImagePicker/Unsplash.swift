//
//  Unsplash.swift
//  Itinera
//
//  Created by Bhumir Patel on 10/28/25.
//

import SwiftUI

public struct UnsplashResponse: Codable {
    public let results: [UnsplashImage]
}

public struct UnsplashImage: Codable, Identifiable {
    public let id: String
    public let urls: UnsplashImageURLs
    public let color: String
    public let blurHash: String
    public let user: UnsplashUser
}

public struct UnsplashImageURLs: Codable {
    public let regular: String
    public let small: String
}

public struct UnsplashUser: Codable {
    public let name: String
    public let profile: String
}
