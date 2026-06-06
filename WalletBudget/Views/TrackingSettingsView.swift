import SwiftUI

/// Sub-page of Settings for how purchases get tracked: setting up Apple Wallet import and
/// managing spending categories. Pushed from `SetupGuideView`.
struct TrackingSettingsView: View {
    @State private var showingOnboarding = false

    var body: some View {
        List {
            Section {
                Button {
                    showingOnboarding = true
                } label: {
                    SettingsRow(assetImage: "applewallet", title: "Set up Apple Wallet tracking")
                }
                .buttonStyle(.plain)
            } footer: {
                Text("Connect the Apple Wallet automation so purchases import into Orbit automatically.")
            }

            Section {
                NavigationLink {
                    ManageCategoriesView()
                } label: {
                    SettingsRow(icon: "tag.fill", tint: .purple, title: "Categories")
                }
                NavigationLink {
                    ManageMerchantsView()
                } label: {
                    SettingsRow(icon: "storefront.fill", tint: .blue, title: "Merchants")
                }
            } footer: {
                Text("Customize your spending categories, or rename a merchant across all of its transactions.")
            }
        }
        .navigationTitle("Tracking")
        .navigationBarTitleDisplayMode(.inline)
        .hidesRootTabBar()
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingFlow()
        }
    }
}
