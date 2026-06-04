import SwiftUI

/// Sub-page of Settings for visual and tactile preferences: app theme and haptic feedback.
/// Pushed from `SetupGuideView`.
struct AppearanceSettingsView: View {
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .system
    @AppStorage(Haptics.enabledKey) private var hapticsEnabled = true

    var body: some View {
        List {
            Section {
                Picker("Theme", selection: $theme) {
                    ForEach(AppTheme.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                Toggle("Haptic Feedback", isOn: $hapticsEnabled)
            } footer: {
                Text("Choose how Wudget looks and whether it responds with haptic taps.")
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}
