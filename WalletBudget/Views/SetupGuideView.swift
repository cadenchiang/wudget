import SwiftUI

/// The Settings tab: a compact, iOS-Settings-style list whose rows each open a focused sub-page.
/// Detailed controls (budget, appearance, privacy, notifications, etc.) live on their own screens
/// so the front page stays short and easy to scan.
struct SetupGuideView: View {
    @Environment(AccountStore.self) private var account
    /// Owned here and shared with `AccountView`, so the avatar on this row and
    /// the one on the profile page are always the same image.
    @State private var avatarStore = ProfileAvatarStore()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        AccountView(avatarStore: avatarStore)
                    } label: {
                        accountRow
                    }
                } header: {
                    Text("Account").textCase(nil)
                }

                Section {
                    NavigationLink { TrackingSettingsView() } label: {
                        SettingsRow(icon: "creditcard.fill", tint: .blue, title: "Tracking")
                    }
                    NavigationLink { BudgetSettingsView() } label: {
                        SettingsRow(icon: "chart.bar.fill", tint: .green, title: "Budget")
                    }
                    NavigationLink { NotificationSettingsView() } label: {
                        SettingsRow(icon: "bell.badge.fill", tint: .red, title: "Notifications")
                    }
                } header: {
                    Text("Spending").textCase(nil)
                }

                Section {
                    NavigationLink { AppearanceSettingsView() } label: {
                        SettingsRow(icon: "paintbrush.fill", tint: .indigo, title: "Appearance")
                    }
                    NavigationLink { PrivacySecuritySettingsView() } label: {
                        SettingsRow(icon: "lock.fill", tint: .gray, title: "Privacy & Security")
                    }
                } header: {
                    Text("App").textCase(nil)
                }

                Section {
                    NavigationLink { AboutView() } label: {
                        SettingsRow(icon: "info.circle.fill", tint: .orange, title: "About")
                    }
                }
            }
            .tabSwipe()
            .topChromeBar {
                Text("Settings")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    /// The account header row: the real profile avatar and the user's name
    /// (never the email — Apple's private-relay addresses are unreadable noise).
    /// Deliberately larger than every other settings row, iOS-Settings style.
    private var accountRow: some View {
        HStack(spacing: 13) {
            ProfileAvatarCircle(image: avatarStore.image, name: account.displayName, diameter: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName ?? "Your Account")
                    .font(.headline)
                    .lineLimit(1)
                Text("Manage profile")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

/// A Settings-style row: a leading icon (asset image, or a plain monochrome SF Symbol — no
/// colored squircle tile), a title, and a chevron. Shared by `SetupGuideView` and its sub-pages.
struct SettingsRow: View {
    /// Asset-catalog image used as the icon (takes precedence over `icon`).
    var assetImage: String? = nil
    /// SF Symbol used when `assetImage` is nil.
    var icon: String = ""
    /// Kept for call-site compatibility; the symbol now always renders monochrome.
    var tint: Color = .primary
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            iconView
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
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
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 29, height: 29)
        }
    }
}

#Preview {
    SetupGuideView()
        .environment(AccountStore())
        .modelContainer(for: [Expense.self, SpendingCategory.self], inMemory: true)
}
