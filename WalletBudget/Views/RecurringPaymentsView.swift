import SwiftUI
import SwiftData

/// Lists transactions marked as recurring, with swipe-to-delete. Tapping one opens its detail.
struct RecurringPaymentsView: View {
    @Environment(\.modelContext) private var context
    @Query(
        filter: #Predicate<Expense> { $0.recurrenceRaw != "none" },
        sort: [SortDescriptor(\Expense.date, order: .reverse)]
    ) private var expenses: [Expense]
    @State private var showingAdd = false

    var body: some View {
        Group {
            if expenses.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(Array(expenses.enumerated()), id: \.element.id) { index, expense in
                        // Hidden NavigationLink so the row keeps its badge instead of the
                        // system chevron.
                        ZStack {
                            NavigationLink { TransactionDetailView(expense: expense) } label: { EmptyView() }
                                .opacity(0)
                            RecurringRow(expense: expense)
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                        // Full-width hairlines (under the logo too); nothing above the first row.
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                        .listRowSeparator(index == 0 ? .hidden : .visible, edges: .top)
                        // Left swipe only: ignore or delete. No leading (right-swipe) actions.
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { delete(expense) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button { toggleExcluded(expense) } label: {
                                Label(expense.excludedFromBudget ? "Include" : "Ignore",
                                      systemImage: expense.excludedFromBudget ? "eye" : "eye.slash")
                            }
                            .tint(.gray)
                        }
                    }

                    Text("Swipe left on a payment to ignore or delete it. Ignored fixed costs raise your budget line instead of counting against it.")
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
        .navigationTitle("Repeat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus")
                }
                .tint(.primary)
                .accessibilityLabel("Add repeating payment")
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddTransactionSheet(recurrenceDefault: .monthly, categoryDefault: "Subscription")
        }
    }

    /// Thin, centered placeholder shown when there are no recurring payments.
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No repeating payments")
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Toggles whether a recurring payment is ignored (excluded from Variable Spending).
    private func toggleExcluded(_ expense: Expense) {
        Haptics.tap()
        expense.excludedFromBudget.toggle()
        expense.updatedAt = Date()
        do {
            try context.save()
            SyncEngine.shared.requestSync()
        } catch {
            Log.ui.error("Failed to toggle exclusion: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Deletes one recurring expense (locally + queued cloud tombstone).
    private func delete(_ expense: Expense) {
        Log.ui.info("Deleting recurring payment at \(expense.merchant, privacy: .public)")
        SyncEngine.shared.delete(expense, context: context)
    }
}

/// A recurring-payment row: merchant logo, merchant, frequency + next due date, amount.
private struct RecurringRow: View {
    let expense: Expense

    /// "Monthly · Next Jun 28"-style subtitle (omits the next date if it can't be computed).
    private var subtitle: String {
        let label = expense.recurrence.label
        guard let next = expense.recurrence.nextOccurrence(from: expense.date) else { return label }
        return "\(label) · Next \(next.formatted(.dateTime.month().day()))"
    }

    var body: some View {
        HStack(spacing: 12) {
            MerchantLogoTile(merchant: expense.merchant)
                .saturation(expense.excludedFromBudget ? 0 : 1)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(expense.merchant.isEmpty ? "Unknown" : expense.merchant)
                        .font(.callout)
                        .foregroundStyle(expense.excludedFromBudget ? Color.secondary : .primary)
                        .lineLimit(1)
                    if expense.excludedFromBudget {
                        HStack(spacing: 3) {
                            Image(systemName: "eye.slash.fill")
                                .font(.system(size: 8, weight: .semibold))
                            Text("IGNORED")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color(.tertiarySystemFill)))
                    }
                }
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            AmountBadge(amount: expense.amount, muted: expense.excludedFromBudget)
        }
        .padding(.vertical, 14)
        .opacity(expense.excludedFromBudget ? 0.6 : 1)
    }
}
