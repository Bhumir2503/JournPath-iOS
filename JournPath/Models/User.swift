//
//  User.swift
//  MyJourney
//
//  Created by Bhumir Patel on 3/17/26.
//

import FirebaseAuth
import Foundation

struct User: Identifiable, Decodable, Sendable {
    // 1. Conforming to Identifiable by mapping 'id' to 'uid'
    var id: String { uid }

    let uid: String
    let displayName: String
    let photoURL: String
    let linkedProviders: [String]
    let createdAt: Date

}
