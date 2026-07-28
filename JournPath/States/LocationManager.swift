import CoreLocation
import Foundation

/// Shared, app-wide location provider.
///
/// Inject a single instance via `.environment(_:)` so every screen shares one
/// `CLLocationManager` and one permission grant, rather than each view model
/// spinning up its own and re-prompting.
///
/// Two usage modes:
/// - `requestLocation()` — a single coarse fix (e.g. to center a search region).
///   Cheap, fires once, stops itself.
/// - `startTracking()` / `stopTracking()` — continuous higher-accuracy updates
///   (e.g. a live user dot on a map). Call `stopTracking()` in `onDisappear`
///   or the GPS keeps draining the battery.
///
/// Assumptions baked in (change if your app differs):
/// - When-In-Use authorization only. No background/Always — add
///   `requestAlwaysAuthorization()` and the matching Info.plist keys if you
///   ever need background location.
/// - Coarse accuracy for one-shot, best accuracy only while actively tracking.
@Observable
@MainActor
final class LocationManager: NSObject, CLLocationManagerDelegate {

    // MARK: - Public state (read-only to consumers)

    /// Latest known coordinate, or nil if never resolved / permission denied.
    private(set) var lastLocation: CLLocationCoordinate2D?

    /// Current system authorization status. Drives UI like "Set location
    /// manually" prompts.
    private(set) var authorizationStatus: CLAuthorizationStatus

    /// True while a continuous tracking session is active.
    private(set) var isTracking = false

    /// Set if the most recent request failed. Consumers can fall back to a
    /// manual location picker when this is non-nil.
    private(set) var lastError: CLError?

    var hasPermission: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    // MARK: - Private

    private let manager = CLLocationManager()

    /// Remembers that a one-shot fix was requested before authorization
    /// resolved, so we can fire it the moment permission is granted.
    private var pendingOneShot = false

    // MARK: - Init

    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    // MARK: - One-shot

    /// Requests a single location fix. Prompts for When-In-Use if the user
    /// hasn't decided yet; the fix fires automatically once granted.
    func requestLocation() {
        lastError = nil
        switch manager.authorizationStatus {
        case .notDetermined:
            pendingOneShot = true
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            break  // consumer should offer a manual picker
        @unknown default:
            break
        }
    }

    // MARK: - Continuous tracking

    /// Starts continuous, high-accuracy updates for a live map dot.
    /// Balance every call with `stopTracking()` (e.g. in `onDisappear`).
    func startTracking() {
        guard hasPermission else {
            // Defer: request permission, then the auth callback starts tracking.
            pendingOneShot = false
            manager.requestWhenInUseAuthorization()
            wantsTracking = true
            return
        }
        beginTracking()
    }

    func stopTracking() {
        wantsTracking = false
        guard isTracking else { return }
        manager.stopUpdatingLocation()
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters  // reset for one-shot callers
        isTracking = false
    }

    private var wantsTracking = false

    private func beginTracking() {
        guard !isTracking else { return }
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.startUpdatingLocation()
        isTracking = true
        wantsTracking = false
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.authorizationStatus = status

            guard status == .authorizedWhenInUse || status == .authorizedAlways else {
                // Permission lost or denied: clear pending intents.
                self.pendingOneShot = false
                self.wantsTracking = false
                return
            }

            if self.wantsTracking {
                self.beginTracking()
            }
            if self.pendingOneShot {
                self.pendingOneShot = false
                self.manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor [weak self] in
            self?.lastLocation = coordinate
            self?.lastError = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            // A transient "unknown location" error before a real fix isn't fatal.
            self?.lastError = error as? CLError
        }
    }
}
