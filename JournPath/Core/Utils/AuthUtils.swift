//
//  AuthUtils.swift
//  MyJourney
//

import FirebaseAuth
import Foundation

// A namespace enum so it can't be accidentally instantiated
enum AuthUtils {
    static func requireUserId() throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(
                domain: "AuthError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]
            )
        }
        return uid
    }
}
