import Foundation

enum StoragePaths {
    static func original(tripId: String, fileId: String, ext: String) -> String {
        "trips/\(tripId)/files/\(fileId)/original.\(ext)"
    }

    static func thumbnail(tripId: String, fileId: String) -> String {
        "trips/\(tripId)/files/\(fileId)/thumb.jpg"
    }

    static func avatar(uid: String) -> String {
        "users/\(uid)/avatar.jpg"
    }
}
