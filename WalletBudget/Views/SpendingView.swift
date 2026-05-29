import SwiftUI
import SwiftData

/// Segments for the spending list: a flat recent feed, or grouped by merchant/category.
private enum SpendingTab: String, CaseIterable, Identifiable {
    case recent
    case merchant
    case category

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: return "Recent"
        case .merchant: return "By Merchant"
        case .category: return "By Category"
        }
    }
}

/// Main screen: a Week/Month/Year selector, a total-spending card with a bar chart, a
/// Recent / By Merchant / By Category selector, and the matching rows below.
struct SpendingView: View {
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @AppStorage("budget.monthly") private var monthlyBudget = 0.0
    @AppStorage("budget.showLine") private var showBudgetLine = true
    @State private var span: TimeSpan = .month
    @State private var tab: SpendingTab = .recent
    @State private var spendingMode: SpendingMode = .total
    @State private var showingAdd = false

    /// Expenses within the selected period (already date-descending from the query).
    private var currentExpenses: [Expense] {
        SpendingSummary.filter(expenses, in: span.interval())
    }

    /// Expenses within the previous period (for deltas/comparison).
    private var previousExpenses: [Expense] {
        SpendingSummary.filter(expenses, in: span.previousInterval())
    }

    /// Current-period expenses honoring the spending mode (Variable excludes fixed costs).
    private var displayedCurrent: [Expense] {
        spendingMode == .variable ? currentExpenses.filter { !$0.excludedFromBudget } : currentExpenses
    }

    /// Previous-period expenses honoring the spending mode.
    private var displayedPrevious: [Expense] {
        spendingMode == .variable ? previousExpenses.filter { !$0.excludedFromBudget } : previousExpenses
    }

    /// The grouping used when not in the Recent tab.
    private var grouping: SpendingGrouping {
        tab == .category ? .category : .merchant
    }

    /// Grouped rows for the current grouping (empty in the Recent tab).
    private var groups: [GroupTotal] {
        guard tab != .recent else { return [] }
        return SpendingSummary.groups(current: currentExpenses, previous: previousExpenses, by: grouping)
    }

    /// Time buckets for the chart x-axis (days for week, day-ranges for month, months for year).
    private var periodBuckets: [PeriodBucket] {
        PeriodBucketizer.buckets(for: span)
    }

    /// Transactions marked as recurring (across all time).
    private var recurringExpenses: [Expense] {
        expenses.filter { $0.recurrence != .none }
    }

    /// A forward-looking pace projection for the current period (nil when not meaningful).
    private var projection: SpendingProjection? {
        let total = SpendingSummary.total(displayedCurrent)
        guard total > 0, let interval = span.interval() else { return nil }
        let now = Date()
        let elapsed = now.timeIntervalSince(interval.start)
        let duration = interval.end.timeIntervalSince(interval.start)
        // Only project once we're meaningfully into the period and still within it.
        guard duration > 0, elapsed > 0, elapsed < duration else { return nil }
        let fraction = elapsed / duration
        guard fraction >= 0.1 else { return nil }
        let projected = total / fraction
        let within = periodBudget.map { projected <= $0 }
        let remaining = periodBudget.map { $0 - total }
        // Whole days left in the period, counting today (interval.end is the exclusive period end).
        let calendar = Calendar.current
        let daysRemaining = max(1, calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: interval.end).day ?? 1)
        return SpendingProjection(amount: projected, periodNoun: periodNoun, isWithinBudget: within, remaining: remaining, daysRemaining: daysRemaining)
    }

    /// Total budget for the current span, scaled from the monthly budget (nil when unset).
    private var periodBudget: Double? {
        guard monthlyBudget > 0 else { return nil }
        switch span {
        case .today: return monthlyBudget / 30.4
        case .week: return monthlyBudget * 7.0 / 30.4
        case .month: return monthlyBudget
        case .year: return monthlyBudget * 12.0
        }
    }

    /// Period noun used in the prediction copy.
    private var periodNoun: String {
        switch span {
        case .today: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        }
    }

    /// The monthly budget scaled to a per-bucket target for the current span (nil when unset).
    private var budgetPerBucket: Double? {
        guard let periodBudget else { return nil }
        let bucketCount = periodBuckets.count
        guard bucketCount > 0 else { return nil }
        return periodBudget / Double(bucketCount)
    }

    var body: some View {
        NavigationStack {
            spendingScroll
                .background(Color(.systemGroupedBackground))
                .topChromeBar { topBar }
                .toolbar(.hidden, for: .navigationBar)
                .sheet(isPresented: $showingAdd) { AddTransactionSheet() }
                .onChange(of: span) { _, _ in Haptics.selection() }
                .onChange(of: tab) { _, _ in Haptics.selection() }
        }
    }

    /// Transparent top bar: period dropdown with date-range subtitle, add button trailing.
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
        let button = Button { Haptics.tap(); showingAdd = true } label: {
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

    /// The spending content: chart card, repeat card, tab selector, and the rows card.
    private var spendingScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TotalSpendingCard(
                    total: SpendingSummary.total(displayedCurrent),
                    previousTotal: SpendingSummary.total(displayedPrevious),
                    segments: SpendingSummary.categorySegments(displayedCurrent, buckets: periodBuckets),
                    bucketLabels: periodBuckets.map(\.label),
                    projection: projection,
                    budgetPerBucket: showBudgetLine ? budgetPerBucket : nil,
                    mode: $spendingMode
                )

                recurringCard

                Picker("View", selection: $tab) {
                    ForEach(SpendingTab.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                if tab == .recent {
                    recentCard
                } else {
                    groupsCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    /// Slim "Repeat" card linking to the recurring-payments list.
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
            .padding(.vertical, 12)
            .background(card)
        }
        .buttonStyle(.plain)
    }

    /// Flat, date-ordered list of the period's transactions (the Recent tab).
    private var recentCard: some View {
        rowsCard(currentExpenses.isEmpty) {
            ForEach(Array(currentExpenses.enumerated()), id: \.element.id) { index, expense in
                NavigationLink {
                    TransactionDetailView(expense: expense)
                } label: {
                    TransactionRow(expense: expense)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)

                if index < currentExpenses.count - 1 {
                    Divider().padding(.leading, 70)
                }
            }
        }
    }

    /// Grouped rows (By Merchant / By Category), each opening the group's transaction list.
    private var groupsCard: some View {
        rowsCard(groups.isEmpty) {
            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                NavigationLink {
                    GroupDetailView(grouping: grouping, key: group.key, interval: span.interval())
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

    /// Wraps rows in the shared card, or shows the empty message.
    @ViewBuilder
    private func rowsCard<Rows: View>(_ isEmpty: Bool, @ViewBuilder rows: () -> Rows) -> some View {
        LazyVStack(spacing: 0) {
            if isEmpty {
                Text("No transactions in this period.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            } else {
                rows()
            }
        }
        .background(card)
    }

    /// Shared rounded card background.
    private var card: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
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
}

#Preview {
    SpendingView()
        .modelContainer(for: Expense.self, inMemory: true)
}
