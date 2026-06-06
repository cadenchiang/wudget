import SwiftUI
import SwiftData
import UIKit

/// "My Cards", full screen: the cards you own, each with this month's spend, an editable credit
/// limit, and a utilization bar colored by credit-score health (green ≤30%, orange ≤50%, red
/// above). Tap a card to edit its limit or remove it; + adds from the full card library. Cards
/// seen on imported transactions are seeded in automatically.
struct CardsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UserCard.createdAt) private var cards: [UserCard]
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @State private var editing: UserCard?
    @State private var addingNew = false

    var body: some View {
        Group {
            if cards.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(sortedCards, id: \.persistentModelID) { card in
                        Button { editing = card } label: { glassCard(row(card)) }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) { delete(card) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }

                    Text("Tap a card to set its credit limit. Keeping utilization under 30% is healthy for your credit score.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 14)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 32, bottom: 16, trailing: 32))
                }
                .listStyle(.plain)
            }
        }
        .background(Color(.systemBackground))
        .swipeToGoBack { dismiss() }
        // Custom chrome so the back and + buttons are the same 40pt glass
        // circles as the spending screen's, not the larger system toolbar ones.
        .toolbar(.hidden, for: .navigationBar)
        .topChromeBar {
            ZStack {
                Text("My Cards")
                    .font(.headline)
                HStack {
                    GlassCircleButton(systemImage: "chevron.left", label: "Back") { dismiss() }
                    Spacer()
                    GlassCircleButton(systemImage: "plus", label: "Add card",
                                      font: .headline.weight(.semibold)) { addingNew = true }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
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

    /// One card row: logo and name on the left, this month's spend big and
    /// unmistakable on the right, with the utilization bar underneath.
    private func row(_ card: UserCard) -> some View {
        let spent = monthSpent(on: card.name)
        let fraction = CardUtilization.fraction(spent: spent, limit: card.creditLimit)
        // Logo pinned to the top-left; every card is the SAME height whether or
        // not it has a gauge, with the bottom line anchored to the bottom edge.
        return HStack(alignment: .top, spacing: 12) {
            cardLogo(card.name)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(card.name)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    // The headline number: what's been spent on this card.
                    Text(spent.asCurrency())
                        .font(.body.weight(.bold))
                        .monospacedDigit()
                }
                Spacer(minLength: 8)
                if let fraction, let limit = card.creditLimit {
                    UtilizationGauge(fraction: fraction)
                    HStack {
                        Text("of \(limit.asCurrency()) limit")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int((fraction * 100).rounded()))% used")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(CardUtilization.tier(for: fraction).color)
                    }
                    .padding(.top, 5)
                } else {
                    // The spend amount is already on the right; no need to repeat it here.
                    Text("Tap to set a credit limit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 64)
        }
        .padding(16)
        .contentShape(Rectangle())
    }

    /// Wraps a row in a Liquid Glass card (material fallback pre-iOS 26) so each
    /// card floats with spacing instead of sharing hairline separators.
    @ViewBuilder
    private func glassCard<Content: View>(_ content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        } else {
            content.background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.thinMaterial))
        }
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

    /// Deletes a card (its transactions stay), locally + queued cloud tombstone.
    private func delete(_ card: UserCard) {
        Log.ui.info("Deleting card \(card.name, privacy: .public)")
        SyncEngine.shared.delete(card, context: context)
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
        SyncEngine.shared.requestSync()
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
            SyncEngine.shared.requestSync()
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
                        SyncEngine.shared.delete(card, context: context)
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
                    CloseToolbarButton { dismiss() }
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
        card.updatedAt = Date()
        save(context: context, action: "save card limit")
        SyncEngine.shared.requestSync()
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

/// Credit-utilization gauge: a fixed gradient of the whole health curve — a
/// LITTLE monthly usage is good for your score (card stays active), the
/// 1–30% band is the sweet spot, and it degrades through orange to red as
/// utilization climbs — with a dot marking where this card sits right now.
private struct UtilizationGauge: View {
    /// Current utilization (spent / limit); values above 1 pin to the end.
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            let x = min(max(fraction, 0), 1) * geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(
                        stops: [
                            .init(color: .orange, location: 0.00), // unused: card looks inactive
                            .init(color: .green, location: 0.10),  // a little spend = healthy
                            .init(color: .green, location: 0.30),  // sweet spot through 30%
                            .init(color: .orange, location: 0.50),
                            .init(color: .red, location: 0.80),
                        ],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(height: 6)
                    .frame(maxHeight: .infinity)

                // The "you are here" dot: pure white in both themes, defined
                // against the gradient by its shadow alone.
                Circle()
                    .fill(.white)
                    .frame(width: 13, height: 13)
                    .position(x: x, y: geo.size.height / 2)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            }
        }
        .frame(height: 14)
    }
}
