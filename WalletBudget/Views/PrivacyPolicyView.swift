import SwiftUI

/// In-app privacy policy for Orbit. Spending data is on-device; the account
/// (email, optional name) lives with our auth provider, and this document says so.
struct PrivacyPolicyView: View {
    var body: some View {
        LegalDocumentView(
            title: "Privacy Policy",
            updated: "June 5, 2026",
            intro: "Orbit is built to keep your financial data private. Your spending data lives on your device and syncs privately to your own account so every device you sign into stays in step. We never sell or share your data.",
            sections: sections
        )
    }

    private var sections: [LegalSection] {
        [
            LegalSection(
                heading: "Your spending data and sync",
                body: "Your transactions (amount, merchant, card name, date, category, and notes), your cards, and your budget are stored on your device and synced to your private account space in our database (hosted by Supabase) so signing in on another device shows the same data. Each account can only ever read its own rows, enforced at the database level. We never sell your data, share it with third parties, or use it for advertising."
            ),
            LegalSection(
                heading: "Your account",
                body: "When you sign up with Apple, Google, or email, we store your email address, your sign-in method, and the display name you choose with our authentication provider (Supabase) so you can sign in."
            ),
            LegalSection(
                heading: "Stays on this device only",
                body: "Your profile photo and the location tags on purchases are stored only on your device and are never uploaded."
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
                heading: "Notifications",
                body: "Reminders (such as upcoming charges and budget alerts) are scheduled and delivered entirely on your device. Nothing about them is sent off your device."
            ),
            LegalSection(
                heading: "No third-party tracking",
                body: "The app does not include analytics, advertising, or third-party tracking SDKs, and does not send your data to third parties."
            ),
            LegalSection(
                heading: "Deleting your data",
                body: "You can delete individual transactions in the app at any time (deletions propagate to your synced account data). Permanently deleting your account from the Account screen removes your email, your profile, and every synced transaction from our database, and erases all spending data stored on this device."
            ),
            LegalSection(
                heading: "Children",
                body: "Orbit is not directed to children under 13 and does not knowingly collect information from them."
            ),
            LegalSection(
                heading: "Changes to this policy",
                body: "We may update this policy from time to time. The date at the top reflects the most recent version."
            ),
            LegalSection(
                heading: "Contact",
                body: "Questions about privacy? Email support@orbitspending.com."
            )
        ]
    }
}
