import SwiftUI
import MapKit
import CoreLocation
import UIKit

/// Location card for a transaction detail screen.
///
/// Shows a real map with a marker and a tap-to-open-in-Maps row when the expense has captured
/// coordinates; otherwise a blurred placeholder with an "Allow Location Access" prompt whose
/// content depends on the current location authorization. Intended to be shown only for Apple
/// Pay / Wallet Import transactions (the caller gates on `viaWalletImport`).
struct TransactionMapCard: View {
    @Environment(\.openURL) private var openURL
    let expense: Expense
    @State private var locationProvider = LocationProvider.shared

    var body: some View {
        if let lat = expense.latitude, let lon = expense.longitude {
            locatedCard(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        } else {
            mapPlaceholder
        }
    }

    /// Real map + place-name row, opening Apple Maps when tapped.
    private func locatedCard(_ coordinate: CLLocationCoordinate2D) -> some View {
        VStack(spacing: 0) {
            Map(initialPosition: .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 500, longitudinalMeters: 500))) {
                Marker(expense.merchant.isEmpty ? "Purchase" : expense.merchant, coordinate: coordinate)
            }
            .frame(height: 170)
            .allowsHitTesting(false)

            Button { openInMaps(coordinate) } label: {
                HStack {
                    Text(placeLabel)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
            }
            .buttonStyle(.plain)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }

    /// Best label for the located place.
    private var placeLabel: String {
        if !expense.locationName.isEmpty { return expense.locationName }
        return expense.merchant.isEmpty ? "Location" : expense.merchant
    }

    /// Blurred map with a location-access prompt (shown when no location is recorded).
    private var mapPlaceholder: some View {
        ZStack {
            Map(initialPosition: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.009),
                latitudinalMeters: 900, longitudinalMeters: 900)))
                .allowsHitTesting(false)
                .blur(radius: 6)
            Color.black.opacity(0.15)
            VStack(spacing: 10) {
                Image(systemName: "mappin.slash")
                    .font(.title)
                    .foregroundStyle(.white)
                locationPrompt
            }
        }
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// The prompt shown over the blurred map, depending on authorization.
    @ViewBuilder
    private var locationPrompt: some View {
        switch locationProvider.authorization {
        case .denied, .restricted:
            Button { openSettings() } label: {
                Label("Allow Location Access", systemImage: "location.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.black)
        case .notDetermined:
            Button { locationProvider.requestAuthorization() } label: {
                Label("Allow Location Access", systemImage: "location.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.black)
        case .authorizedWhenInUse:
            // Staged escalation: offer the Always upgrade needed for background tagging.
            Button { locationProvider.requestAuthorization() } label: {
                Label("Enable Background Tagging", systemImage: "location.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.black)
        default:
            Text("No location recorded")
                .font(.subheadline)
                .foregroundStyle(.white)
        }
    }

    /// Opens the location in Apple Maps.
    private func openInMaps(_ coordinate: CLLocationCoordinate2D) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = placeLabel
        item.openInMaps()
    }

    /// Opens the app's Settings page (for re-enabling denied location access).
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }
}
