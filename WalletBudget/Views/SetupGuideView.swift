import SwiftUI

/// The Settings tab: a compact, iOS-Settings-style list whose rows each open a focused sub-page.
/// Detailed controls (budget, appearance, privacy, notifications, etc.) live on their own screens
/// so the front page stays short and easy to scan.
struct SetupGuideView: View {
    @Environment(AccountStore.self) private var account

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        AccountView()
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
                }

                Section {
                    NavigationLink { AppearanceSettingsView() } label: {
                        SettingsRow(icon: "paintbrush.fill", tint: .indigo, title: "Appearance")
                    }
                    NavigationLink { PrivacySecuritySettingsView() } label: {
                        SettingsRow(icon: "lock.fill", tint: .gray, title: "Privacy & Security")
                    }
                }

                Section {
                    NavigationLink { AboutView() } label: {
                        SettingsRow(icon: "info.circle.fill", tint: .orange, title: "About")
                    }
                }
            }
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

    /// The account header row: profile glyph, signed-in email, and a "Manage profile" subtitle.
    private var accountRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.gray)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.email ?? "Account")
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text("Manage profile")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A Settings-style row: a leading icon (asset image or SF Symbol tile), a title, and a chevron.
/// Shared by `SetupGuideView` and its sub-pages.
struct SettingsRow: View {
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
        .environment(AccountStore())
        .modelContainer(for: [Expense.self, SpendingCategory.self], inMemory: true)
}
