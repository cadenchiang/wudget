import SwiftUI
import SwiftData

/// Lists the individual transactions behind a tapped group (category or merchant) within the
/// selected period, rendered with the same card/row layout as the home Recent list.
struct GroupDetailView: View {
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
        ScrollView {
            LazyVStack(spacing: 0) {
                if periodExpenses.isEmpty {
                    Text("No transactions in this period.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                } else {
                    ForEach(Array(periodExpenses.enumerated()), id: \.element.id) { index, expense in
                        NavigationLink {
                            TransactionDetailView(expense: expense)
                        } label: {
                            TransactionRow(expense: expense)
                        }
                        .buttonStyle(.plain)

                        if index < periodExpenses.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .background(Color(.systemBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
