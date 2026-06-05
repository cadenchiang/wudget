import SwiftUI
import SwiftData
import UIKit

/// "My Cards": every card you've paid with, summarized. Reached from the credit-card button on
/// the spending screen, presented as a partial-height glass sheet. Each row shows the card's
/// logo, name, transaction count, and total spent, sorted by total descending.
struct CardsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]

    /// One card's lifetime summary.
    private struct CardSummary: Identifiable {
        var id: String { name }
        let name: String
        let count: Int
        let total: Double
    }

    /// Distinct cards from all transactions (empty card strings excluded), largest spend first.
    private var summaries: [CardSummary] {
        var totals: [String: (count: Int, total: Double)] = [:]
        for expense in expenses where !expense.card.isEmpty {
            let canonical = CardMatcher.match(expense.card)
            var entry = totals[canonical] ?? (0, 0)
            entry.count += 1
            entry.total += expense.amount
            totals[canonical] = entry
        }
        return totals
            .map { CardSummary(name: $0.key, count: $0.value.count, total: $0.value.total) }
            .sorted { $0.total > $1.total }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if summaries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(summaries.enumerated()), id: \.element.id) { index, summary in
                            row(summary)
                            if index < summaries.count - 1 {
                                Divider().padding(.leading, 72)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .presentationDetents([.fraction(0.82), .large])
        .glassSheetBackground(cornerRadius: 36)
        .presentationCornerRadius(36)
        .presentationDragIndicator(.visible)
    }

    /// Close button and centered title, matching the add-transaction sheet.
    private var header: some View {
        ZStack {
            Text("My Cards")
                .font(.headline)
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(.thinMaterial))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 16)
    }

    /// One card row: logo tile, name + transaction count, total spent.
    private func row(_ summary: CardSummary) -> some View {
        HStack(spacing: 12) {
            cardLogo(summary.name)
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.name)
                    .font(.body.weight(.semibold))
                Text("\(summary.count) transaction\(summary.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(summary.total.asCurrency())
                .font(.body.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    /// The card's bundled logo (when known), else a card glyph on a gray tile.
    @ViewBuilder
    private func cardLogo(_ name: String) -> some View {
        if let item = CardLibrary.item(named: name),
           let asset = item.assetName, UIImage(named: asset) != nil {
            ZStack {
                Color.white
                Image(asset)
                    .resizable()
                    .scaledToFill()
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.gray.gradient)
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)
        }
    }

    /// Thin, centered placeholder shown when no transactions carry a card yet.
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "creditcard")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Cards you pay with will show up here")
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    CardsView()
        .modelContainer(for: Expense.self, inMemory: true)
}
