import Observation
import SwiftUI

// MARK: - App Routes
enum AppRoute: Hashable {
    case settings
    case notifications
    case tripDashboard(tripId: String)
    case tripMap(tripId: String)
}

// MARK: - App Router
@Observable
final class AppRouter {
    var path = NavigationPath()
    @ObservationIgnored @AppStorage("lastTripId") var lastTripId: String?

    func navigateToSettings() {
        path.append(AppRoute.settings)
    }

    func navigateToNotifications() {
        path.append(AppRoute.notifications)
    }

    func navigateToTrip(tripId: String) {
        lastTripId = tripId
        path.append(AppRoute.tripDashboard(tripId: tripId))
    }

    func navigateToTripMap(tripId: String) {
        path.append(AppRoute.tripMap(tripId: tripId))
    }

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        lastTripId = nil
        path = NavigationPath()
    }

    func restoreLastTripIfNeeded() {
        if let lastTripId = lastTripId {
            navigateToTrip(tripId: lastTripId)
        }
    }
}
