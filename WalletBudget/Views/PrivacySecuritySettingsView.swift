import SwiftUI
import CoreLocation
import UIKit

/// Sub-page of Settings for privacy and security: the Face ID app lock and whether imported
/// purchases are tagged with their location. Pushed from `SetupGuideView`.
struct PrivacySecuritySettingsView: View {
    @Environment(\.openURL) private var openURL
    @AppStorage(AppLock.enabledKey) private var lockEnabled = false
    @AppStorage(LocationProvider.taggingEnabledKey) private var locationTagging = true
    @State private var locationProvider = LocationProvider.shared

    var body: some View {
        List {
            securitySection
            locationSection
        }
        .navigationTitle("Privacy & Security")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var securitySection: some View {
        Section {
            Toggle("Require Face ID", isOn: $lockEnabled)
        } header: {
            Text("Security").textCase(nil)
        } footer: {
            Text("Lock Orbit so it can only be opened with Face ID.")
        }
    }

    private var locationSection: some View {
        Section {
            Toggle("Tag purchases with location", isOn: $locationTagging)
            if locationTagging { locationStatusRow }
        } header: {
            Text("Location").textCase(nil)
        } footer: {
            Text(locationFooter)
        }
    }

    /// A status-aware row prompting for permission when location tagging is on but not yet usable.
    @ViewBuilder
    private var locationStatusRow: some View {
        switch locationProvider.authorization {
        case .notDetermined:
            Button("Allow Location Access") { locationProvider.requestAuthorization() }
        case .authorizedWhenInUse:
            // Staged escalation: When-In-Use is granted; offer the Always upgrade
            // that background Wallet imports need to tag purchase locations.
            Button("Enable Background Tagging") { locationProvider.requestAuthorization() }
        case .denied, .restricted:
            Button("Open Settings to Enable") { openSystemSettings() }
        default:
            EmptyView()
        }
    }

    /// Footer text explaining the current location state and what is needed for background imports.
    private var locationFooter: String {
        guard locationTagging else {
            return "Imported purchases will not record where they happened."
        }
        switch locationProvider.authorization {
        case .denied, .restricted:
            return "Location is turned off for Orbit in iOS Settings. Locations stay on your device."
        case .authorizedWhenInUse:
            return "Set location access to “Always” in iOS Settings so purchases can be tagged when the import runs in the background. Locations stay on your device."
        default:
            return "Purchases imported from Apple Pay are tagged with their location. Locations stay on your device."
        }
    }

    /// Opens the app's page in iOS Settings (to change location permission).
    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }
}
