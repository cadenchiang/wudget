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
                    ForEach(expenses) { expense in
                        NavigationLink {
                            TransactionDetailView(expense: expense)
                        } label: {
                            RecurringRow(expense: expense)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .listRowSeparator(.hidden, edges: expense == expenses.last ? .bottom : [])
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
                }
                .listStyle(.plain)
                .safeAreaInset(edge: .bottom) {
                    Text("Swipe left on a payment to ignore or delete it. Ignored fixed costs raise your budget line instead of counting against it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 10)
                }
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
        do {
            try context.save()
        } catch {
            Log.ui.error("Failed to toggle exclusion: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Deletes one recurring expense and saves.
    private func delete(_ expense: Expense) {
        Log.ui.info("Deleting recurring payment at \(expense.merchant, privacy: .public)")
        context.delete(expense)
        do {
            try context.save()
        } catch {
            Log.ui.error("Failed to delete recurring payment: \(error.localizedDescription, privacy: .public)")
        }
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
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(expense.merchant.isEmpty ? "Unknown" : expense.merchant)
                        .font(.body.weight(.semibold))
                    if expense.excludedFromBudget {
                        Text("Ignored")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color(.tertiarySystemFill)))
                    }
                }
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(expense.amount.asCurrency())
                .font(.body.weight(.medium))
        }
        .opacity(expense.excludedFromBudget ? 0.55 : 1)
    }
}
