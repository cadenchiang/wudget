import SwiftUI

/// The Setup tab, styled like the iOS Settings app: a grouped list whose row opens the
/// full-screen, step-by-step onboarding flow (`OnboardingFlow`).
struct SetupGuideView: View {
    @Environment(AccountStore.self) private var account
    @State private var showingOnboarding = false
    @AppStorage(Haptics.enabledKey) private var hapticsEnabled = true
    @AppStorage(AppLock.enabledKey) private var lockEnabled = false
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .system
    @AppStorage("budget.monthly") private var monthlyBudget = 0.0
    @AppStorage("budget.showLine") private var showBudgetLine = true

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        AccountView()
                    } label: {
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
                } header: {
                    Text("Account").textCase(nil)
                }

                Section {
                    Button {
                        showingOnboarding = true
                    } label: {
                        SettingsRow(assetImage: "applewallet", title: "Set up Apple Wallet tracking")
                    }
                    .buttonStyle(.plain)

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
                } header: {
                    Text("Tracking").textCase(nil)
                }

                Section {
                    NavigationLink {
                        BudgetEditorView()
                    } label: {
                        HStack {
                            Text("Monthly Budget")
                            Spacer()
                            Text(monthlyBudget > 0 ? monthlyBudget.asCurrency() : "None")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle("Show Budget Line", isOn: $showBudgetLine)
                } header: {
                    Text("Budget").textCase(nil)
                } footer: {
                    Text("Shown as a target line on the spending chart. Mark fixed costs as “Ignored” in Repeat to budget only variable spending.")
                }

                Section {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        SettingsRow(icon: "bell.badge.fill", tint: .red, title: "Notifications")
                    }
                    Picker("Theme", selection: $theme) {
                        ForEach(AppTheme.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    Toggle("Haptic Feedback", isOn: $hapticsEnabled)
                    Toggle("Require Face ID", isOn: $lockEnabled)
                } header: {
                    Text("Preferences").textCase(nil)
                }

                Section {
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
            .topChromeBar {
                Text("Settings")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
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
