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

    var authorization: CLAuthorizationStatus = .notDetermined

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var continuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        authorization = manager.authorizationStatus
    }

    /// Requests "Always" access so the automation can tag transactions in the background.
    func requestAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    /// One-shot current location, or `nil` if unavailable/unauthorized (4s timeout so it never hangs).
    func currentLocation() async -> CLLocation? {
        let status = manager.authorizationStatus
        guard status == .authorizedAlways || status == .authorizedWhenInUse else { return nil }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
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
        finish(with: locations.last)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(with: nil)
    }
}
