import SwiftUI

/// The Setup tab, styled like the iOS Settings app: a grouped list whose row opens the
/// full-screen, step-by-step onboarding flow (`OnboardingFlow`).
struct SetupGuideView: View {
    @State private var showingOnboarding = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showingOnboarding = true
                    } label: {
                        SettingsRow(assetImage: "applewallet", title: "Set up Apple Wallet tracking")
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Wallet").textCase(nil)
                } footer: {
                    Text("Log Apple Pay purchases automatically.")
                }

                Section {
                    NavigationLink {
                        ManageCategoriesView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "tag")
                                .font(.system(size: 22))
                                .foregroundStyle(.purple)
                                .frame(width: 29, height: 29)
                            Text("Categories").foregroundStyle(.primary)
                        }
                    }

                    NavigationLink {
                        AboutView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 24))
                                .foregroundStyle(.orange)
                                .frame(width: 29, height: 29)
                            Text("About").foregroundStyle(.primary)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                Text("Settings")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                    .background(Color(.systemGroupedBackground))
            }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showingOnboarding) {
                OnboardingFlow()
            }
        }
    }
}

/// A Settings-style row: a leading icon (asset image or SF Symbol tile), a title, and a chevron.
private struct SettingsRow: View {
    /// Asset-catalog image used as the icon (takes precedence over `icon`/`tint`).
    var assetImage: String? = nil
    /// SF Symbol used when `assetImage` is nil.
    var icon: String = ""
    /// Tile color when using an SF Symbol.
    var tint: Color = .blue
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            iconView
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let assetImage {
            Image(assetImage)
                .resizable()
                .scaledToFit()
                .frame(width: 29, height: 29)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        } else {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 29, height: 29)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(tint))
        }
    }
}

#Preview {
    SetupGuideView()
}
