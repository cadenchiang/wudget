import CoreLocation
import Observation

/// Provides one-shot device location for tagging Wallet Import transactions, and tracks the
/// authorization status so the UI can prompt for access.
///
/// The Wallet Import intent calls `currentLocation()` on every import (best-effort): if access is
/// granted it returns the current location, otherwise `nil`. The map placeholder uses
/// `authorization` to show an "Allow Location Access" prompt.
@Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    static let shared = LocationProvider()

    /// `@AppStorage` / `UserDefaults` key for the user's "tag purchases with location" preference.
    /// Defaults to enabled (treated as `true` when unset) so existing behavior is preserved.
    static let taggingEnabledKey = "location.taggingEnabled"

    /// Whether location tagging is currently enabled by the user (defaults to `true` when unset).
    static var isTaggingEnabled: Bool {
        UserDefaults.standard.object(forKey: taggingEnabledKey) as? Bool ?? true
    }

    var authorization: CLAuthorizationStatus = .notDetermined

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var continuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        authorization = manager.authorizationStatus
        // Allow a one-shot fix while the Wallet automation runs the import in the background.
        // CoreLocation aborts the process if this is set without the `location` UIBackgroundMode
        // (declared in WalletBudget/Info.plist), so verify the mode is actually present in the
        // built bundle before opting in. Guards against build-config drift silently dropping it.
        let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        if backgroundModes.contains("location") {
            manager.allowsBackgroundLocationUpdates = true
            manager.pausesLocationUpdatesAutomatically = false
        } else {
            // Cause: built Info.plist lacks the `location` background mode.
            // Impact: background Wallet imports are saved without a location; foreground unaffected.
            Log.location.error("UIBackgroundModes missing 'location'; background location capture disabled")
        }
    }

    /// Requests location access using Apple's staged pattern (App Review guideline
    /// 5.1.5 expects this): first ask for When-In-Use, and only once that is
    /// granted escalate to "Always" so background Wallet imports can tag where a
    /// purchase happened. Each UI tap advances one stage; foreground tagging
    /// already works at When-In-Use, so nothing breaks between stages.
    func requestAuthorization() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            // Denied/restricted can only be changed in Settings; already-Always needs nothing.
            Log.location.info("Authorization request skipped (status raw \(self.manager.authorizationStatus.rawValue))")
        }
    }

    /// One-shot current location, or `nil` if unavailable/unauthorized (4s timeout so it never hangs).
    func currentLocation() async -> CLLocation? {
        let status = manager.authorizationStatus
        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            // Cause: not authorized. Impact: import is saved without a location.
            Log.location.info("Skipping location capture: not authorized (status raw \(status.rawValue))")
            return nil
        }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                guard self?.continuation != nil else { return }
                // Cause: no fix arrived within the timeout. Impact: import saved without a location.
                Log.location.error("Location request timed out after 4s; recording transaction without location")
                self?.finish(with: nil)
            }
        }
    }

    /// Reverse-geocodes a location to a city/place name.
    func placeName(for location: CLLocation) async -> String? {
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
        guard let mark = placemarks?.first else { return nil }
        return mark.locality ?? mark.name ?? mark.administrativeArea
    }

    private func finish(with location: CLLocation?) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: location)
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if locations.last != nil {
            Log.location.info("Captured device location for transaction tagging")
        }
        finish(with: locations.last)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Cause: Core Location failed (e.g. no fix, denied). Impact: import saved without a location.
        Log.location.error("Location request failed: \(error.localizedDescription, privacy: .public)")
        finish(with: nil)
    }
}
