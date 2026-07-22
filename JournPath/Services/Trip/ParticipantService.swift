import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import Foundation

final class ParticipantService {
    func kickParticipant(tripId: String, kickedUserId: String) async throws(APIError) {
        let data: [String: Any] = [
            "tripId": tripId,
            "targetUid": kickedUserId,
        ]
        try await APIClient.shared.post("/trip/kick", body: data)
    }

    func undoKickParticipant(tripId: String, kickedUserId: String) async throws(APIError) {
        let data: [String: Any] = [
            "tripId": tripId,
            "targetUid": kickedUserId,
        ]
        try await APIClient.shared.post("/trip/unkick", body: data)
    }

    func changeRole(tripId: String, userId: String, role: ParticipantRole) async throws(APIError) {
        let data: [String: Any] = [
            "tripId": tripId,
            "targetUid": userId,
            "newRole": role.rawValue,
        ]
        try await APIClient.shared.post("/trip/updateRole", body: data)
    }
}
