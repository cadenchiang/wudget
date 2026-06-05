import SwiftUI
import UIKit

/// About page: app icon, name, and version, followed by Support and Legal sections.
struct AboutView: View {
    @Environment(\.openURL) private var openURL
    @State private var copied = false

    /// Display name from the bundle (falls back to "Orbit").
    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Orbit"
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
                    Image("AppIconImage")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    row("Privacy Policy", icon: "hand.raised", orangeText: true)
                }
                NavigationLink {
                    TermsOfServiceView()
                } label: {
                    row("Terms of Service", icon: "doc.text", orangeText: true)
                }
            }

            // Required attribution for the Logo.dev free plan, which serves merchant/card logos.
            Section("Credits") {
                Button { openURL(URL(string: "https://logo.dev")!) } label: {
                    row("Logos provided by Logo.dev", icon: "photo.on.rectangle", orangeText: true)
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

    /// Opens the Mail app with a pre-filled support email (subject, body, recipient).
    private func emailSupport() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "support@orbitspending.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Orbit Support"),
            URLQueryItem(name: "body", value: "\n\n\n\(appName) \(versionString)")
        ]
        if let url = components.url {
            openURL(url)
        }
    }

    /// Copies the app name + version to the clipboard and briefly shows "Copied!".
    private func copyBuildInfo() {
        UIPasteboard.general.string = "\(appName) \(versionString)"
        Haptics.tap()
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }
}
