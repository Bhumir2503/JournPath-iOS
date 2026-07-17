import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import Foundation

final class ParticipantService {
    func kickParticipant(tripId: String, kickedUserId: String) async throws {
        let functions = Functions.functions()
        let data: [String: Any] = [
            "tripId": tripId,
            "participantId": kickedUserId
        ]
        _ = try await functions.httpsCallable("kickParticipant").call(data)
    }

    func undoKickParticipant(tripId: String, kickedUserId: String) async throws {
        let functions = Functions.functions()
        let data: [String: Any] = [
            "tripId": tripId,
            "participantId": kickedUserId
        ]
        _ = try await functions.httpsCallable("unkickParticipant").call(data)
    }

    func changeRole(tripId: String, userId: String, role: ParticipantRole) async throws {
        AppLogger.viewModels.info("changing role of user id: \(userId) to role: \(role.rawValue)")
        let functions = Functions.functions()
        let data: [String: Any] = [
            "tripId": tripId,
            "participantId": userId,
            "role": role.rawValue
        ]
        _ = try await functions.httpsCallable("updateParticipantRole").call(data)
    }
}
