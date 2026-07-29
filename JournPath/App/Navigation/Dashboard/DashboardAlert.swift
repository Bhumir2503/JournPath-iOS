import SwiftUI

enum DashboardAlert: Identifiable, Hashable {
    case rename, leave, tripDeleted, removed, upgraded
    case error(String)

    var id: Self { self }

    var title: String {
        switch self {
        case .rename: "Rename Trip"
        case .leave: "Leave Trip?"
        case .tripDeleted: "Trip Deleted"
        case .removed: "Removed From Trip"
        case .upgraded: "Premium Access Unlocked"
        case .error: "Something Went Wrong"
        }
    }

    var message: String? {
        switch self {
        case .rename: nil
        case .leave: "You'll lose access to this trip's itinerary, expenses, and files."
        case .tripDeleted: "This trip has been deleted and is no longer available."
        case .removed: "You've been removed from this trip."
        case .upgraded: "You now have access to premium features."
        case .error(let m): m
        }
    }

    /// These pop the user out of the trip rather than dismissing in place.
    var isTerminal: Bool {
        self == .tripDeleted || self == .removed
    }
}

extension View {
    func dashboardAlert(
        _ alert: Binding<DashboardAlert?>,
        onLeave: @escaping () -> Void,
        onRename: @escaping (String) -> Void
    ) -> some View {
        modifier(DashboardAlertModifier(alert: alert, onLeave: onLeave, onRename: onRename))
    }
}

private struct DashboardAlertModifier: ViewModifier {
    @Binding var alert: DashboardAlert?
    let onLeave: () -> Void
    let onRename: (String) -> Void

    @Environment(AppRouter.self) private var router
    @State private var renameText = ""

    func body(content: Content) -> some View {
        content.alert(
            alert?.title ?? "",
            isPresented: Binding(get: { alert != nil }, set: { if !$0 { alert = nil } }),
            presenting: alert
        ) { current in
            switch current {
            case .rename:
                TextField("Trip name", text: $renameText)
                Button("Save") { onRename(renameText) }
                Button("Cancel", role: .cancel) {}
            case .leave:
                Button("Leave", role: .destructive, action: onLeave)
                Button("Cancel", role: .cancel) {}
            case .tripDeleted, .removed:
                Button("OK") { router.popToRoot() }
            case .upgraded, .error:
                Button("OK", role: .cancel) {}
            }
        } message: { current in
            if let message = current.message { Text(message) }
        }
    }
}
