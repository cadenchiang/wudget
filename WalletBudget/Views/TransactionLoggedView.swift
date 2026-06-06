import SwiftUI

/// Full-screen confirmation shown right after a transaction is saved
/// (Robinhood-order-complete style), deliberately rendered in the OPPOSITE
/// color scheme — dark app gets a light takeover and vice versa — so the
/// moment reads as a distinct "done" beat. Shows the saved amount, merchant,
/// and card, with a Done pill and a View Transaction link.
struct TransactionLoggedView: View {
    /// The expense that was just saved.
    let expense: Expense
    /// Dismisses the whole add flow (this cover and the add sheet beneath it).
    let onDone: () -> Void
    /// Dismisses the add flow and pushes the transaction's detail screen in
    /// Spending (the same screen tapping its row opens — not a pop-up).
    let onView: () -> Void

    /// Merchant with the same fallback used by the transaction lists.
    private var merchantName: String {
        expense.merchant.isEmpty ? "Unknown" : expense.merchant
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Fixed palette regardless of theme: black backdrop, white card.
            Color.black.ignoresSafeArea()
            card
                .padding(.horizontal, 28)
                .padding(.top, 148)
        }
    }

    /// The confirmation card (Robinhood-order-complete style): always white with
    /// black text (forced light scheme), sitting high on a black screen.
    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Transaction Logged")
                .font(.title3.bold())
            Text("Your \(expense.amount.asCurrency()) purchase at \(merchantName) is saved.")
                .font(.subheadline)
                .foregroundStyle(.black)
                .padding(.top, 12)

            VStack(spacing: 0) {
                row("Amount", expense.amount.asCurrency())
                Divider()
                row("Merchant", merchantName)
                if !expense.card.isEmpty {
                    Divider()
                    row("Card", expense.card)
                }
            }
            .padding(.top, 26)

            Button {
                Haptics.tap()
                onDone()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Capsule().fill(.black))
            }
            .buttonStyle(.plain)
            .padding(.top, 26)

            Button("View Transaction") {
                Haptics.tap()
                onView()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
        )
        .environment(\.colorScheme, .light)
    }

    /// One label/value line of the summary, all black on the white card.
    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.black)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.callout)
        .padding(.vertical, 15)
    }
}

