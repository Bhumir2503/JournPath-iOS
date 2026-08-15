import SwiftUI

enum DashboardAlert: Identifiable, Hashable {
    case rename, leave, upgraded
    case error(String)

    var id: Self { self }

    var title: String {
        switch self {
        case .rename: "Rename Trip"
        case .leave: "Leave Trip?"
        case .upgraded: "Premium Access Unlocked"
        case .error: "Something Went Wrong"
        }
    }

    var message: String? {
        switch self {
        case .rename: nil
        case .leave: "You'll lose access to this trip's itinerary, expenses, and files."
        case .upgraded: "You now have access to premium features."
        case .error(let m): m
        }
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

    @Environment(TripStore.self) private var trip
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
                TextField("Trip name", text: $renameText).onChange(of: renameText) { if renameText.count > 32 { renameText = String(renameText.prefix(32)) } }
                Button("Save") { onRename(renameText) }.disabled(trip.name == renameText || renameText.isEmpty)
                    .keyboardShortcut(.defaultAction)
                Button("Cancel", role: .cancel) {}
            case .leave:
                Button("Cancel") {}
                    .keyboardShortcut(.defaultAction)
                Button("Leave") { onLeave() }

            case .upgraded, .error:
                Button("OK", role: .cancel) {}
                    .keyboardShortcut(.defaultAction)
            }
        } message: { current in
            if let message = current.message { Text(message) }
        }
    }
}
