import FirebaseAuth
import Kingfisher
import SwiftUI

struct ParticipantListView: View {
    @Environment(SessionStore.self) private var user
    @Environment(TripStore.self) private var trip
    @State private var participantManager: ParticipantStore

    private var participantService = ParticipantService()

    @State private var participantToKick: Participant?
    @State private var showKickAlert = false
    @State private var participantForRoleChange: Participant?

    @State private var error: AnyAppError? = nil

    init(tripId: String) {
        _participantManager = State(initialValue: ParticipantStore(tripId: tripId))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    activeSection
                    removedSection
                }

                swipeHint
                inviteButton
            }
            .background(Color.systemGroupedBackground)
            .onAppear { participantManager.start() }
            .onDisappear { participantManager.stop() }
            .navigationTitle("Participants")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Kick Member?", isPresented: $showKickAlert, presenting: participantToKick) { participant in
                Button("Remove", role: .destructive) { kickParticipant(participant: participant) }
                Button("Cancel", role: .cancel) {}
            } message: { participant in
                Text("Are you sure you want to remove \(participant.displayName) from the trip? They will lose access to all shared content.")
            }
            .sheet(item: $participantForRoleChange) { participant in
                RoleSelectionSheet(
                    participant: participant,
                    assignableRoles: participantManager.assignableRoles(for: participant),
                    onCancel: { participantForRoleChange = nil }
                )
            }
        }
    }

    // MARK: - Sections

    private var activeSection: some View {
        Section {
            ForEach(participantManager.sortedParticipants, id: \.id) { participant in
                ParticipantRow(
                    participant: participant,
                    isCurrentUser: participant.id == user.uid
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if participantManager.canKick(participant: participant) {
                        Button {
                            participantToKick = participant
                            showKickAlert = true
                        } label: {
                            Label("Remove", systemImage: "person.badge.minus")
                        }
                        .tint(.red)
                    }

                    if participantManager.canChangeRole(of: participant) {
                        Button {
                            participantForRoleChange = participant
                        } label: {
                            Label("Role", systemImage: "person.badge.key")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var removedSection: some View {
        if participantManager.isCaptain && !participantManager.kickedParticipants.isEmpty {
            Section("Removed") {
                ForEach(participantManager.kickedParticipants, id: \.id) { participant in
                    ParticipantRow(
                        participant: participant,
                        isCurrentUser: participant.id == user.uid
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            restoreParticipant(participant: participant)
                        } label: {
                            Label("Restore", systemImage: "arrow.uturn.backward")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var swipeHint: some View {
        if participantManager.isCaptain {
            HStack(spacing: 6) {
                Image(systemName: "hand.draw")
                    .foregroundColor(.secondary)
                Text("Swipe left on a member to change their role or remove them.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private var inviteButton: some View {
        if let url = shareURL {
            ShareLink(item: url, preview: SharePreview(sharePreviewTitle)) {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                    Text("Add More Members")
                }
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue)
                .clipShape(Capsule())
                .padding(.horizontal)
            }
            .buttonStyle(.plain)
        } else {
            Text("Unable to generate invite link.")
                .foregroundColor(.red)
                .padding()
        }
    }

    // MARK: - Share payload

    var shareURL: URL? {
        // 1. Build the path string with the tripId interpolated
        let path = "https://journpath.com/invite/trip/\(trip.tripId)"

        // 2. Use URLComponents to safely add the token query parameter
        var components = URLComponents(string: path)
        components?.queryItems = [
            URLQueryItem(name: "token", value: trip.inviteToken)
        ]

        return components?.url
    }

    var sharePreviewTitle: String {
        "Join me on my trip to \"\(trip.name)\" on JournPath"
    }

    // MARK: - Actions

    func kickParticipant(participant: Participant) {
        guard let targetId = participant.id else { return }
        Task {
            do {
                try await participantService.kickParticipant(tripId: trip.tripId, kickedUserId: targetId)
            } catch let error as LocalizedError {
                self.error = AnyAppError(error)
            }
        }
    }

    func restoreParticipant(participant: Participant) {
        guard let targetId = participant.id else { return }
        Task {
            do {
                try await participantService.undoKickParticipant(tripId: trip.tripId, kickedUserId: targetId)
            } catch let error as LocalizedError {
                self.error = AnyAppError(error)
            }
        }
    }
}

struct ParticipantRow: View {
    let participant: Participant
    let isCurrentUser: Bool

    var body: some View {
        HStack {
            ParticipantAvatar(
                photoURL: participant.photoURL,
                fallbackInitial: participant.displayName.prefix(1).uppercased()
            )

            VStack(alignment: .leading) {
                HStack(alignment: .center) {
                    Text(participant.displayName)
                        .font(.headline)
                    if isCurrentUser {
                        Text("(You)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Text(participant.role.rawValue.capitalized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

        }
    }
}

struct ParticipantAvatar: View {
    let photoURL: String?
    let fallbackInitial: String

    var body: some View {
        if let photoURLString = photoURL, let url = URL(string: photoURLString) {
            KFImage(url)
                .placeholder { placeholderCircle }
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
        } else {
            placeholderCircle
                .overlay(Text(fallbackInitial).foregroundColor(.white))
        }
    }

    private var placeholderCircle: some View {
        Circle()
            .fill(Color.gray)
            .frame(width: 40, height: 40)
    }
}
