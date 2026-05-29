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
                    }
                    .onDelete(perform: delete)
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
            AddTransactionSheet(recurrenceDefault: .monthly)
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

    /// Deletes the recurring expenses at the given offsets and saves.
    /// - Parameter offsets: Index set provided by `onDelete`, relative to `expenses`.
    private func delete(at offsets: IndexSet) {
        for expense in offsets.map({ expenses[$0] }) {
            Log.ui.info("Deleting recurring payment at \(expense.merchant, privacy: .public)")
            context.delete(expense)
        }
        do {
            try context.save()
        } catch {
            Log.ui.error("Failed to delete recurring payment(s): \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// A recurring-payment row: category-colored icon, merchant, frequency + next due date, amount.
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
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(CategoryStyle.color(for: expense.category).gradient)
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: CategoryStyle.icon(for: expense.category))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.merchant.isEmpty ? "Unknown" : expense.merchant)
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(expense.amount.asCurrency())
                .font(.body.weight(.medium))
        }
        .padding(.vertical, 6)
    }
}
