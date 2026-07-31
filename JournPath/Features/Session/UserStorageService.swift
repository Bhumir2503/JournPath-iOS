//
//  UserStorageService.swift
//  MyJourney
//

import FirebaseStorage
import Foundation

class UserStorageService {
    private let storage = Storage.storage()

    func uploadProfilePhoto(uid: String, data: Data) async throws -> URL {
        let storageRef = storage.reference().child("users/\(uid)/profile.jpg")
        let uploadMetadata = StorageMetadata()
        uploadMetadata.contentType = "image/jpeg"
        return try await withCheckedThrowingContinuation { continuation in
            storageRef.putData(data, metadata: uploadMetadata) { metadata, error in
                if let error = error {
                    print("Upload error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    storageRef.downloadURL { url, error in
                        if let error = error {
                            print("Download url error: \(error.localizedDescription)")
                            continuation.resume(throwing: error)
                        } else if let url = url {
                            continuation.resume(returning: url)
                        } else {
                            continuation.resume(throwing: URLError(.badServerResponse))
                        }
                    }
                }
            }
        }
    }
}
