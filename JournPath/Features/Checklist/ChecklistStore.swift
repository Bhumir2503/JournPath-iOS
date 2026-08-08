import FirebaseFirestore
import Foundation
import Observation

@MainActor
@Observable
final class ChecklistStore {

    private(set) var lists: [Checklist] = []
    private(set) var items: [ChecklistItem] = []
    private(set) var isLoaded: Bool = false
    private(set) var isItemsLoaded: Bool = false

    private let tripId: String
    private let uid: String
    @ObservationIgnored private var listListener: ListenerRegistration?
    @ObservationIgnored private var itemListener: ListenerRegistration?

    init(tripId: String, uid: String) {
        self.tripId = tripId
        self.uid = uid
    }

    deinit {
        listListener?.remove()
        itemListener?.remove()
    }

    // MARK: Lifecycle

    func start() {
        guard listListener == nil else { return }

        listListener = Firestore.firestore()
            .collection("trips").document(tripId)
            .collection("checklists")
            .whereFilter(Filter.orFilter([
                Filter.whereField("kind", isEqualTo: ChecklistKind.shared.rawValue),
                Filter.whereField("createdBy", isEqualTo: uid)
            ]))
            .order(by: "sortIndex")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    AppLogger.store.error("[ChecklistStore] Failed to load checklists: \(error.localizedDescription)")
                    return
                }
                guard let snapshot else {
                    AppLogger.store.error("[ChecklistStore] No snapshot received")
                    return
                }

                let decoded = snapshot.documents.compactMap { doc in
                    try? doc.data(as: Checklist.self, with: .estimate)
                }

                self.lists = decoded
                self.isLoaded = true

                // On first load, start listening to the first list automatically.
                // If selectedListId is already set (user switched chips), leave it alone.
                if self.selectedListId == nil {
                    self.selectedListId = decoded.first?.id
                }
            }
    }

    func stop() {
        listListener?.remove()
        listListener = nil
        itemListener?.remove()
        itemListener = nil
        selectedListId = nil
    }

    // MARK: Selection

    /// Setting this tears down the old items listener and opens a new one for
    /// the chosen list. The VM sets this when the user taps a chip.
    var selectedListId: String? {
        didSet {
            guard selectedListId != oldValue else { return }
            startItemListener()
        }
    }

    private func startItemListener() {
        itemListener?.remove()
        itemListener = nil
        items = []
        isItemsLoaded = false

        guard let selectedListId else { return }

        itemListener = Firestore.firestore()
            .collection("trips").document(tripId)
            .collection("checklists").document(selectedListId)
            .collection("items")
            .order(by: "position")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    AppLogger.store.error("[ChecklistStore] Failed to load checklist items: \(error.localizedDescription)")
                    self.isItemsLoaded = true
                    return
                }
                guard let snapshot else {
                    self.isItemsLoaded = true
                    return
                }

                self.items = snapshot.documents.compactMap { doc in
                    try? doc.data(as: ChecklistItem.self, with: .estimate)
                }
                self.isItemsLoaded = true
            }
    }
}
