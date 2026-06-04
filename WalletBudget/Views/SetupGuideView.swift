import SwiftUI

/// The Settings tab, styled like Robinhood's Menu: airy typography-led rows (title + one-line
/// summary + chevron) separated by hairlines on the plain background. No icons, no boxes.
/// Detailed controls (budget, appearance, privacy, notifications, etc.) live on their own screens.
struct SetupGuideView: View {
    @Environment(AccountStore.self) private var account

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    menuLink(title: account.email ?? "Account", subtitle: "Manage profile") {
                        AccountView()
                    }
                    menuLink(title: "Tracking", subtitle: "Apple Wallet automation, spending mode") {
                        TrackingSettingsView()
                    }
                    menuLink(title: "Budget", subtitle: "Monthly limit and progress") {
                        BudgetSettingsView()
                    }
                    menuLink(title: "Notifications", subtitle: "Alerts and summaries") {
                        NotificationSettingsView()
                    }
                    menuLink(title: "Appearance", subtitle: "Theme and haptics") {
                        AppearanceSettingsView()
                    }
                    menuLink(title: "Privacy & Security", subtitle: "Face ID lock, location") {
                        PrivacySecuritySettingsView()
                    }
                    menuLink(title: "About", subtitle: "Version, support, legal", showsDivider: false) {
                        AboutView()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
            .background(Color(.systemBackground))
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

    /// One menu row: bold title over a one-line gray summary, a trailing chevron, and a hairline
    /// underneath (except the last row).
    private func menuLink<Destination: View>(
        title: String,
        subtitle: String,
        showsDivider: Bool = true,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        VStack(spacing: 0) {
            NavigationLink {
                destination()
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 18)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if showsDivider {
                Divider()
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
