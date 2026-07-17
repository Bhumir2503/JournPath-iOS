import FirebaseAuth
import FirebaseFirestore
import Foundation

class AttachmentDatabaseService {
    private let db = Firestore.firestore()

    func listenToAttachments(tripId: String, onUpdate: @escaping (_ attachments: [Attachment], _ removedAttachments: [Attachment]) -> Void) -> () -> Void {

        let query = db.collection("trips").document(tripId).collection("attachments")
            .order(by: "createdAt", descending: false)

        let listener = query.addSnapshotListener { snapshot, error in
            guard let snapshot = snapshot else {
                AppLogger.database.error("Error fetching trip files: \(error?.localizedDescription ?? "Unknown")")
                return
            }

            var attachments: [Attachment] = []
            var removedAttachments: [Attachment] = []

            // 1. Decode all active files
            for document in snapshot.documents {
                do {
                    let file = try document.data(as: Attachment.self)
                    attachments.append(file)
                } catch {
                    AppLogger.database.error("Failed to decode TripFile (\(document.documentID)): \(error)")
                }
            }

            // 2. Safely parse ONLY the files that were deleted/archived so the VM can clean the cache
            for change in snapshot.documentChanges {
                if change.type == .removed {
                    do {
                        let removedFile = try change.document.data(as: Attachment.self)
                        removedAttachments.append(removedFile)
                    } catch {
                        AppLogger.database.error("Failed to decode removed TripFile (\(change.document.documentID)): \(error)")
                    }
                }
            }

            // 3. Pass clean, native Swift objects back to the ViewModel
            onUpdate(attachments, removedAttachments)
        }

        // Return a generic action that cancels the Firebase listener when called!
        return {
            listener.remove()
        }
    }

    func renameAttachment(tripId: String, attachmentId: String, newName: String) async throws {
        try await db.collection("trips").document(tripId).collection("attachments").document(attachmentId).updateData([
            "name": newName
        ])
    }

    func deleteAttachment(tripId: String, attachmentId: String) async throws {
        try await db.collection("trips").document(tripId).collection("attachments").document(attachmentId).delete()
    }
}
