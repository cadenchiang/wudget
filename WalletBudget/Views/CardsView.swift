import SwiftUI
import SwiftData
import UIKit

/// "My Cards", full screen: the cards you own, each with this month's spend, an editable credit
/// limit, and a utilization bar colored by credit-score health (green ≤30%, orange ≤50%, red
/// above). Tap a card to edit its limit or remove it; + adds from the full card library. Cards
/// seen on imported transactions are seeded in automatically.
struct CardsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \UserCard.createdAt) private var cards: [UserCard]
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @State private var editing: UserCard?
    @State private var addingNew = false

    var body: some View {
        Group {
            if cards.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(sortedCards.enumerated()), id: \.element.persistentModelID) { index, card in
                            Button { editing = card } label: { row(card) }
                                .buttonStyle(.plain)
                            if index < sortedCards.count - 1 {
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("My Cards")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { addingNew = true } label: { Image(systemName: "plus") }
                    .tint(.primary)
                    .accessibilityLabel("Add card")
            }
        }
        .safeAreaInset(edge: .bottom) {
            Text("Tap a card to set its credit limit. Keeping utilization under 30% is healthy for your credit score.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.vertical, 10)
        }
        .sheet(item: $editing) { card in
            CardEditorSheet(card: card)
        }
        .sheet(isPresented: $addingNew) {
            LibraryPickerView(title: "Card", items: CardLibrary.items, fallbackIcon: "creditcard.fill", style: .list) { name in
                editing = addCardIfNeeded(named: name)
            }
        }
        .onAppear(perform: seedFromTransactions)
    }

    /// Cards by this month's spend (descending), then by creation order.
    private var sortedCards: [UserCard] {
        cards.sorted { lhs, rhs in
            let l = monthSpent(on: lhs.name)
            let r = monthSpent(on: rhs.name)
            return l == r ? lhs.createdAt < rhs.createdAt : l > r
        }
    }

    /// This calendar month's spending on a card (matching canonicalized transaction card names).
    private func monthSpent(on name: String) -> Double {
        guard let month = TimeSpan.month.interval() else { return 0 }
        return expenses
            .filter { month.contains($0.date) && !$0.card.isEmpty && CardMatcher.match($0.card) == name }
            .reduce(0) { $0 + $1.amount }
    }

    /// One card row: logo, name, spend / limit, and the utilization bar.
    private func row(_ card: UserCard) -> some View {
        let spent = monthSpent(on: card.name)
        let fraction = CardUtilization.fraction(spent: spent, limit: card.creditLimit)
        return HStack(spacing: 12) {
            cardLogo(card.name)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(card.name)
                        .font(.body.weight(.semibold))
                    Spacer()
                    if let fraction {
                        Text("\(Int((fraction * 100).rounded()))%")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(CardUtilization.tier(for: fraction).color)
                    }
                }
                if let fraction, let limit = card.creditLimit {
                    ProgressView(value: min(fraction, 1))
                        .tint(CardUtilization.tier(for: fraction).color)
                    Text("\(spent.asCurrency()) of \(limit.asCurrency()) this month")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(spent > 0
                         ? "\(spent.asCurrency()) this month · tap to set a limit"
                         : "Tap to set a credit limit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
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

    /// Thin, centered placeholder shown before any cards exist.
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "creditcard")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Add the cards you pay with")
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Returns the existing card with this name, or inserts (and returns) a new one.
    @discardableResult
    private func addCardIfNeeded(named name: String) -> UserCard {
        if let existing = cards.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return existing
        }
        let card = UserCard(name: name)
        context.insert(card)
        save(context: context, action: "add card")
        return card
    }

    /// Seeds a `UserCard` for every canonical card already present on transactions, so imported
    /// history shows up in My Cards without manual setup.
    private func seedFromTransactions() {
        let known = Set(cards.map { $0.name.lowercased() })
        var seen = Set<String>()
        for expense in expenses where !expense.card.isEmpty {
            let canonical = CardMatcher.match(expense.card)
            let key = canonical.lowercased()
            if !known.contains(key) && !seen.contains(key) {
                seen.insert(key)
                context.insert(UserCard(name: canonical))
            }
        }
        if !seen.isEmpty {
            save(context: context, action: "seed cards")
            Log.ui.info("Seeded \(seen.count) cards from transactions")
        }
    }
}

/// Saves a model context, logging the action and any failure (no silent drops).
private func save(context: ModelContext, action: String) {
    do {
        try context.save()
    } catch {
        Log.ui.error("Failed to \(action, privacy: .public): \(error.localizedDescription, privacy: .public)")
    }
}

/// Editor for one card: set/clear its credit limit, or remove the card entirely.
private struct CardEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var card: UserCard
    @State private var limitText = ""
    @FocusState private var limitFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Credit limit") {
                    TextField("e.g. 5000", text: $limitText)
                        .keyboardType(.decimalPad)
                        .focused($limitFocused)
                }
                Section {
                    Button(role: .destructive) {
                        context.delete(card)
                        save(context: context, action: "delete card")
                        dismiss()
                    } label: {
                        Text("Remove Card")
                    }
                } footer: {
                    Text("Removing a card doesn't delete its transactions.")
                }
            }
            .navigationTitle(card.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { commit() }
                }
            }
            .onAppear {
                if let limit = card.creditLimit {
                    limitText = limit.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
                }
                limitFocused = true
            }
        }
        .presentationDetents([.height(320)])
        .glassSheetBackground(cornerRadius: 28)
        .presentationCornerRadius(28)
        .presentationDragIndicator(.visible)
    }

    /// Stores the parsed limit (empty clears it) and dismisses.
    private func commit() {
        let trimmed = limitText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            card.creditLimit = nil
        } else if let value = CurrencyParser.parse(trimmed), value > 0 {
            card.creditLimit = value
        } else {
            Log.ui.error("Rejected card limit input: \(limitText, privacy: .public)")
            return
        }
        save(context: context, action: "save card limit")
        Haptics.success()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        CardsView()
    }
    .modelContainer(for: [Expense.self, UserCard.self], inMemory: true)
}
