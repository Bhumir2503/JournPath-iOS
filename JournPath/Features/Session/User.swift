//
//  User.swift
//  MyJourney
//
//  Created by Bhumir Patel on 3/17/26.
//

import FirebaseFirestore
import FirebaseAuth
import Foundation

struct User: Identifiable, Decodable, Sendable {
    @DocumentID var id: String?
    let displayName: String
    let photoURL: String
}
