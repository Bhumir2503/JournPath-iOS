import Foundation
import Network
import SwiftUI

enum NetworkError: Error {
    case networkUnavailable
}

@Observable
final class NetworkMonitor {
    // 1. Singleton access
    static let shared = NetworkMonitor()

    // 2. Network framework monitor and background queue
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")

    // 3. Observable state for the UI
    var isConnected: Bool = true
    var connectionType: ConnectionType = .unknown

    enum ConnectionType {
        case wifi, cellular, ethernet, unknown
    }

    // 4. Private initializer starts monitoring immediately
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            // NWPathMonitor updates happen on a background thread.
            // @Observable handles thread safety automatically when updating UI,
            // but updating our properties explicitly updates dependent views.
            Task { @MainActor in
                self.isConnected = (path.status == .satisfied)
                self.determineInterfaceType(path)
            }
        }
        monitor.start(queue: queue)
    }

    func checkConnection() throws {
        guard isConnected else {
            throw NetworkError.networkUnavailable
        }
    }

    private func determineInterfaceType(_ path: NWPath) {
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }
    }
}
