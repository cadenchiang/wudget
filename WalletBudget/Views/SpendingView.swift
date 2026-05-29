import SwiftUI
import SwiftData

/// Main screen: a Week/Month/Year selector, a total-spending card with a bar chart, a By
/// Merchant / By Category toggle, and grouped spending rows that drill into their transactions.
struct SpendingView: View {
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @State private var span: TimeSpan = .month
    @State private var grouping: SpendingGrouping = .merchant
    @State private var showingAdd = false

    /// Expenses within the selected period.
    private var currentExpenses: [Expense] {
        SpendingSummary.filter(expenses, in: span.interval())
    }

    /// Expenses within the previous period (for deltas/comparison).
    private var previousExpenses: [Expense] {
        SpendingSummary.filter(expenses, in: span.previousInterval())
    }

    /// Grouped rows for the current grouping mode.
    private var groups: [GroupTotal] {
        SpendingSummary.groups(current: currentExpenses, previous: previousExpenses, by: grouping)
    }

    /// Time buckets for the chart x-axis (days for week, day-ranges for month, months for year).
    private var periodBuckets: [PeriodBucket] {
        PeriodBucketizer.buckets(for: span)
    }

    var body: some View {
        NavigationStack {
            spendingScroll
                .background(Color(.systemGroupedBackground))
                .topChromeBar { topBar }
                .toolbar(.hidden, for: .navigationBar)
                .sheet(isPresented: $showingAdd) { AddTransactionSheet() }
        }
    }

    /// Transparent top bar: period dropdown on the left, add button on the right.
    private var topBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 1) {
                spanMenu
                Text(span.dateRange())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            addButton
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    /// The add (+) button on a Liquid Glass circle (falls back to a material circle pre-iOS 26).
    @ViewBuilder
    private var addButton: some View {
        let button = Button { showingAdd = true } label: {
            Image(systemName: "plus")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
        }
        .tint(.primary)
        .accessibilityLabel("Add transaction")

        if #available(iOS 26.0, *) {
            button.glassEffect(.regular.interactive(), in: .circle)
        } else {
            button.background(Circle().fill(.thinMaterial))
        }
    }

    /// The spending content.
    private var spendingScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TotalSpendingCard(
                    total: SpendingSummary.total(currentExpenses),
                    previousTotal: SpendingSummary.total(previousExpenses),
                    segments: SpendingSummary.categorySegments(currentExpenses, buckets: periodBuckets),
                    bucketLabels: periodBuckets.map(\.label)
                )

                recurringCard

                Picker("Grouping", selection: $grouping) {
                    ForEach(SpendingGrouping.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                groupsCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    /// Transactions marked as recurring (across all time).
    private var recurringExpenses: [Expense] {
        expenses.filter { $0.recurrence != .none }
    }

    /// A slim card linking to the recurring-payments list.
    private var recurringCard: some View {
        NavigationLink {
            RecurringPaymentsView()
        } label: {
            HStack(spacing: 8) {
                Text("Repeat")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(recurringExpenses.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }

    /// The period dropdown (transparent, no background).
    private var spanMenu: some View {
        Menu {
            Picker("Time span", selection: $span) {
                ForEach(TimeSpan.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(span.title)
                    .font(.title3.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.primary)
        }
        .tint(.primary)
        .accessibilityLabel("Time span: \(span.title)")
    }

    /// The grouped rows inside a single rounded card, or an empty message.
    private var groupsCard: some View {
        VStack(spacing: 0) {
            if groups.isEmpty {
                Text("No transactions in this period.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            } else {
                ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                    NavigationLink {
                        destination(for: group)
                    } label: {
                        SpendingGroupRow(group: group, grouping: grouping)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)

                    if index < groups.count - 1 {
                        Divider().padding(.leading, 70)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    /// The current-period expenses belonging to a group.
    private func expenses(for group: GroupTotal) -> [Expense] {
        currentExpenses.filter { expense in
            switch grouping {
            case .category: return expense.category == group.key
            case .merchant: return (expense.merchant.isEmpty ? "Unknown" : expense.merchant) == group.key
            }
        }
    }

    /// Destination for tapping a group.
    ///
    /// By Merchant: a single transaction opens its detail directly; multiple opens the list.
    /// By Category: always opens the list of that category's transactions.
    @ViewBuilder
    private func destination(for group: GroupTotal) -> some View {
        let items = expenses(for: group)
        if grouping == .merchant, items.count == 1 {
            TransactionDetailView(expense: items[0])
        } else {
            GroupDetailView(grouping: grouping, key: group.key, interval: span.interval())
        }
    }
}

#Preview {
    SpendingView()
        .modelContainer(for: Expense.self, inMemory: true)
}
