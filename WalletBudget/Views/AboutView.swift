import SwiftUI
import UIKit

/// About page: app icon, name, and version, followed by Support and Legal sections.
struct AboutView: View {
    @Environment(\.openURL) private var openURL
    @State private var copied = false

    /// Display name from the bundle (falls back to "WalletBudget").
    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "WalletBudget"
    }

    /// "Version 1.0 (1)"-style string from the bundle.
    private var versionString: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.accentColor.gradient)
                        .frame(width: 72, height: 72)
                        .overlay {
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    Text(appName).font(.title3.bold())
                    Text(versionString).font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            Section("Support") {
                Button { emailSupport() } label: {
                    row("Email support", icon: "envelope", orangeText: true)
                }
                Button { copyBuildInfo() } label: {
                    row(copied ? "Copied!" : "Copy build info", icon: "doc.on.doc", orangeText: true)
                }
            }

            Section("Legal") {
                Link(destination: URL(string: "https://walletbudget.app/privacy")!) {
                    row("Privacy Policy", icon: "hand.raised", orangeText: true)
                }
                Link(destination: URL(string: "https://walletbudget.app/terms")!) {
                    row("Terms of Service", icon: "doc.text", orangeText: true)
                }
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// A support/legal row: orange icon with title (orange title for links).
    private func row(_ title: String, icon: String, orangeText: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.orange)
                .frame(width: 24)
            Text(title)
                .foregroundStyle(orangeText ? Color.orange : Color.primary)
        }
    }

    /// Opens the support email composer.
    private func emailSupport() {
        if let url = URL(string: "mailto:support@walletbudget.app") {
            openURL(url)
        }
    }

    /// Copies the app name + version to the clipboard.
    private func copyBuildInfo() {
        UIPasteboard.general.string = "\(appName) — \(versionString)"
        copied = true
    }
}
