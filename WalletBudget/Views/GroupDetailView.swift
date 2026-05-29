import SwiftUI
import SwiftData

/// Lists the individual transactions behind a tapped group (category or merchant) within
/// the selected period, with swipe-to-delete.
struct GroupDetailView: View {
    @Environment(\.modelContext) private var context

    private let title: String
    private let interval: DateInterval?
    @Query private var expenses: [Expense]

    /// Creates the detail view for one group.
    /// - Parameters:
    ///   - grouping: Whether `key` is a category or a merchant.
    ///   - key: The category/merchant value to show.
    ///   - interval: The period interval to restrict transactions to (nil = no bound).
    init(grouping: SpendingGrouping, key: String, interval: DateInterval?) {
        self.title = key
        self.interval = interval
        let predicate: Predicate<Expense>
        switch grouping {
        case .category:
            predicate = #Predicate { $0.category == key }
        case .merchant:
            predicate = #Predicate { $0.merchant == key }
        }
        _expenses = Query(filter: predicate, sort: [SortDescriptor(\Expense.date, order: .reverse)])
    }

    /// Expenses for this group restricted to the selected period.
    private var periodExpenses: [Expense] {
        SpendingSummary.filter(expenses, in: interval)
    }

    var body: some View {
        List {
            ForEach(periodExpenses) { expense in
                NavigationLink {
                    TransactionDetailView(expense: expense)
                } label: {
                    ExpenseRow(expense: expense)
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if periodExpenses.isEmpty {
                ContentUnavailableView("No transactions", systemImage: "creditcard")
            }
        }
    }

    /// Deletes the expenses at the given offsets and saves.
    /// - Parameter offsets: Index set provided by `onDelete`, relative to `periodExpenses`.
    private func delete(at offsets: IndexSet) {
        for expense in offsets.map({ periodExpenses[$0] }) {
            Log.ui.info("Deleting transaction at \(expense.merchant, privacy: .public)")
            context.delete(expense)
        }
        do {
            try context.save()
        } catch {
            Log.ui.error("Failed to delete transaction(s): \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// A single transaction row: merchant + category over amount + date.
struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.merchant.isEmpty ? "Unknown" : expense.merchant)
                Text(expense.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(expense.amount.asCurrency())
                    .fontWeight(.medium)
                Text(expense.date, format: .dateTime.month().day())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
