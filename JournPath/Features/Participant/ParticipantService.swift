import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import Foundation

final class ParticipantService {
    func kick(_ participantId: String, in tripId: String) async throws(APIError) {
        let data: [String: Any] = [
            "tripId": tripId,
            "targetUid": participantId,
        ]
        try await APIClient.shared.post("/trip/kick", body: data)
    }

    func restore(_ participantId: String, in tripId: String) async throws(APIError) {
        let data: [String: Any] = [
            "tripId": tripId,
            "targetUid": participantId,
        ]
        try await APIClient.shared.post("/trip/restore", body: data)
    }

    func promote(_ participantId: String, to role: ParticipantRole, in tripId: String) async throws(APIError) {
        let data: [String: Any] = [
            "tripId": tripId,
            "targetUid": participantId,
            "newRole": role.rawValue,
        ]
        try await APIClient.shared.post("/trip/promote", body: data)
    }
}
