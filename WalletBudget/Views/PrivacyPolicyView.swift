import SwiftUI

/// In-app privacy policy for Wudget. Reflects the app's on-device, no-backend model.
struct PrivacyPolicyView: View {
    var body: some View {
        LegalDocumentView(
            title: "Privacy Policy",
            updated: "May 29, 2026",
            intro: "Wudget is built to keep your financial data private. Everything you track stays on your device. We don't run servers that store your data, and we never sell or share it.",
            sections: sections
        )
    }

    private var sections: [LegalSection] {
        [
            LegalSection(
                heading: "Data stored on your device",
                body: "Your transactions (amount, merchant, card name, date, category, and notes), your budget, and your preferences are stored locally on your device using Apple's on-device database. This information is not transmitted to us or to any server."
            ),
            LegalSection(
                heading: "Location",
                body: "If you grant location permission, the app tags purchases imported from Apple Pay with their location so it can show them on a map. This location data is stored only on your device. You can deny or turn off location access at any time in iOS Settings, and location never leaves your device."
            ),
            LegalSection(
                heading: "Apple Wallet and Apple Pay",
                body: "The app cannot read your Apple Wallet or your cards. Transactions arrive only from a Shortcut you choose to set up, which passes along the amount, merchant, and card name you map. We have no access to your bank or card accounts."
            ),
            LegalSection(
                heading: "No accounts or servers",
                body: "Any sign-in information is kept on your device. We do not operate a backend that holds your personal information."
            ),
            LegalSection(
                heading: "Notifications",
                body: "Reminders (such as upcoming charges and budget alerts) are scheduled and delivered entirely on your device. Nothing about them is sent off your device."
            ),
            LegalSection(
                heading: "No third-party tracking",
                body: "The app does not include analytics, advertising, or third-party tracking SDKs, and does not send your data to third parties."
            ),
            LegalSection(
                heading: "Deleting your data",
                body: "You can delete individual transactions in the app at any time. Deleting the app removes all data it stored on your device."
            ),
            LegalSection(
                heading: "Children",
                body: "Wudget is not directed to children under 13 and does not knowingly collect information from them."
            ),
            LegalSection(
                heading: "Changes to this policy",
                body: "We may update this policy from time to time. The date at the top reflects the most recent version."
            ),
            LegalSection(
                heading: "Contact",
                body: "Questions about privacy? Email support@walletbudget.app."
            )
        ]
    }
}
