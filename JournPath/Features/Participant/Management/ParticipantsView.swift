import FirebaseAuth
import Kingfisher
import SwiftUI

struct ParticipantsView: View {
    @Environment(SessionStore.self) private var user
    @Environment(TripStore.self) private var trip
    @Environment(ParticipantStore.self) private var participant

    /// Injected as a default so previews and tests can substitute.
    private let participantService: ParticipantService

    init(participantService: ParticipantService = ParticipantService()) {
        self.participantService = participantService
    }

    /// IDs with a write in flight. Swipe actions fire instantly and a listener
    /// echo takes a beat, so without this a fast second swipe sends the call
    /// twice.
    @State private var pendingIDs: Set<String> = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // One List, two Sections — not two Lists. Stacking two Lists
                // in a VStack gives you two independent scroll views splitting
                // the screen, and neither can use the full height.
                List {
                    activeSection
                    formerSection
                }
                swipeHint
                inviteButton
            }
            .background(Color.systemGroupedBackground)
            .navigationTitle("Participants")
            .navigationBarTitleDisplayMode(.inline)
            .alert(
                "Something went wrong",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Sections

    private var activeSection: some View {
        Section {
            ForEach(participant.participants) { member in
                ParticipantRow(
                    participant: member,
                    isCurrentUser: member.id == user.uid
                )
                .disabled(isPending(member))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {

                    if ParticipantPermissions.canKick(member, by: participant.me) {
                        Button {
                            kick(member)
                        } label: {
                            Label("Kick", systemImage: "person.slash")
                        }
                        .tint(.red)
                    }

                    if ParticipantPermissions.canChangeRole(of: member, to: .captain, by: participant.me, in: participant.participants) {
                        Button {
                            promote(member)
                        } label: {
                            Label("Make Captain", systemImage: "crown.fill")
                        }
                        .tint(.green)
                    }
                }
            }
        } header: {
            Text("On the trip")
        }
    }

    @ViewBuilder
    private var formerSection: some View {
        // No empty section: a "Former" header over nothing reads like a bug.
        if !participant.formerParticipants.isEmpty {
            Section {
                ForEach(participant.formerParticipants) { member in
                    ParticipantRow(
                        participant: member,
                        isCurrentUser: member.id == user.uid
                    )
                    .disabled(isPending(member))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if ParticipantPermissions.canRestore(member, by: participant.me) {
                            Button {
                                restore(member)
                            } label: {
                                Label("Add back", systemImage: "person.badge.plus")
                            }
                            .tint(.green)
                        }
                    }
                }
            } header: {
                Text("No longer on the trip")
            } footer: {
                Text("Their expenses, documents and itinerary entries stay on the trip.")
            }
        }
    }

    // MARK: - Actions

    private func isPending(_ member: Participant) -> Bool {
        member.id.map(pendingIDs.contains) ?? false
    }

    private func promote(_ member: Participant) {
        perform(member) { id in
            try await participantService.promote(id, to: .captain, in: participant.tripId)
        }
    }

    private func kick(_ member: Participant) {
        perform(member) { id in
            try await participantService.kick(id, in: participant.tripId)
        }
    }

    private func restore(_ member: Participant) {
        perform(member) { id in
            try await participantService.restore(id, in: participant.tripId)
        }
    }

    /// Shared in-flight bookkeeping and error surfacing. `id` is unwrapped once
    /// here rather than force-unwrapped at each call site — a nil document ID
    /// means the snapshot decoded oddly, which is a log line, not a crash.
    private func perform(
        _ member: Participant,
        action: @escaping (String) async throws -> Void
    ) {
        guard let id = member.id else {
            AppLogger.managers.error("[ParticipantsView] Participant with no document ID")
            return
        }
        guard !pendingIDs.contains(id) else { return }

        pendingIDs.insert(id)
        Task {
            defer { pendingIDs.remove(id) }
            do {
                try await action(id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Chrome

    /// Shown only when there's actually something swipeable, and worded for
    /// what the swipe does — there's no role editor on this screen.
    @ViewBuilder
    private var swipeHint: some View {
        if hasAnySwipeAction {
            HStack(spacing: 6) {
                Image(systemName: "hand.draw")
                Text("Swipe left on a member to remove or re-add them.")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            .padding(.bottom, 12)
        }
    }

    private var hasAnySwipeAction: Bool {
        participant.participants.contains {
            ParticipantPermissions.canKick($0, by: participant.me)
        }
            || participant.formerParticipants.contains {
                ParticipantPermissions.canRestore($0, by: participant.me)
            }
    }

    @ViewBuilder
    private var inviteButton: some View {
        if ParticipantPermissions.canInvite(participant.me), let url = trip.shareURL {
            ShareLink(item: url, preview: SharePreview("Join me on my trip: \(trip.name)!")) {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                    Text("Add More Members")
                }
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.brand)
                .clipShape(.capsule)
                .padding(.horizontal)
            }
            .buttonStyle(.plain)
        }
    }
}
