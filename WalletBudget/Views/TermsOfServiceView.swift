import SwiftUI

/// In-app terms of service for Budget.
struct TermsOfServiceView: View {
    var body: some View {
        LegalDocumentView(
            title: "Terms of Service",
            updated: "May 29, 2026",
            intro: "By using Budget, you agree to these terms. Please read them.",
            sections: sections
        )
    }

    private var sections: [LegalSection] {
        [
            LegalSection(
                heading: "The service",
                body: "Budget helps you track and budget your spending on your device. It is a personal-finance tool, not a bank or financial institution, and it does not move, hold, or transfer money."
            ),
            LegalSection(
                heading: "Not financial advice",
                body: "The information and calculations the app provides are for your own budgeting and are not professional financial, tax, or investment advice."
            ),
            LegalSection(
                heading: "Your data and accuracy",
                body: "You are responsible for the transactions and amounts you enter or import. The app reflects the data it is given, and its totals and projections are only as accurate as that data."
            ),
            LegalSection(
                heading: "Acceptable use",
                body: "Use the app lawfully and for your personal budgeting. Do not attempt to misuse, disrupt, or reverse engineer the app except to the extent permitted by law."
            ),
            LegalSection(
                heading: "No warranty",
                body: "The app is provided \"as is\" and \"as available,\" without warranties of any kind, whether express or implied."
            ),
            LegalSection(
                heading: "Limitation of liability",
                body: "To the maximum extent permitted by law, we are not liable for any losses or damages arising from your use of the app or your reliance on its calculations."
            ),
            LegalSection(
                heading: "Apple's terms",
                body: "Your use of the app is also subject to Apple's standard Licensed Application End User License Agreement."
            ),
            LegalSection(
                heading: "Changes to these terms",
                body: "We may update these terms from time to time. Continued use of the app after an update means you accept the revised terms."
            ),
            LegalSection(
                heading: "Contact",
                body: "Questions about these terms? Email support@walletbudget.app."
            )
        ]
    }
}
