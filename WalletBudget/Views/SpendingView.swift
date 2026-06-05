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
    @AppStorage("budget.enabled") private var budgetEnabled = true
    @AppStorage(ProfileKeys.variableDefault) private var variableDefault = false
    @State private var span: TimeSpan = .month
    @State private var tab: SpendingTab = .recent
    @AppStorage("spending.mode") private var spendingMode: SpendingMode = .total
    @AppStorage("spending.modeSeeded") private var modeSeeded = false
    @State private var showingAdd = false
    /// Anchors the sliding pill of the period selector.
    @Namespace private var spanPillNamespace

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

    /// Previous-period expenses truncated to the same elapsed point we've reached in the current
    /// period, so the comparison reads "last period *at this time*" (e.g. last month's first week)
    /// rather than last period's full total. Falls back to the whole previous period if intervals
    /// can't be computed.
    private var comparablePrevious: [Expense] {
        guard let current = span.interval(), let previous = span.previousInterval() else {
            return displayedPrevious
        }
        let elapsed = min(max(0, Date().timeIntervalSince(current.start)), current.duration)
        let cutoff = previous.start.addingTimeInterval(elapsed)
        return displayedPrevious.filter { $0.date <= cutoff }
    }

    /// The grouping used when not in the Recent tab.
    private var grouping: SpendingGrouping {
        tab == .category ? .category : .merchant
    }

    /// Grouped rows for the current grouping (empty in the Recent tab).
    /// Uses the mode-aware set so ignored items drop out of the breakdown in Variable mode.
    private var groups: [GroupTotal] {
        guard tab != .recent else { return [] }
        return SpendingSummary.groups(current: displayedCurrent, previous: displayedPrevious, by: grouping)
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

    /// Total budget for the current span, scaled from the monthly budget.
    /// `nil` when the user has turned the budget off or hasn't set one, which removes the
    /// budget line, the over/under coloring, and the remaining-to-spend sentence everywhere.
    private var periodBudget: Double? {
        guard budgetEnabled, monthlyBudget > 0 else { return nil }
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
                .background(Color(.systemBackground))
                .topChromeBar { topBar }
                .toolbar(.hidden, for: .navigationBar)
                .sheet(isPresented: $showingAdd) { AddTransactionSheet() }
                .onChange(of: span) { _, _ in Haptics.selection() }
                .onChange(of: tab) { _, _ in Haptics.selection() }
                .onAppear {
                    // Seed the mode from the onboarding preference only once, ever. After that the
                    // user's last choice is restored from @AppStorage on every launch.
                    if !modeSeeded {
                        spendingMode = variableDefault ? .variable : .total
                        modeSeeded = true
                    }
                }
        }
    }

    /// Transparent top bar: title with the selected period's date range, add button trailing.
    /// (Period selection lives in the chip slider under the chart.)
    private var topBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Spending")
                    .font(.title3.weight(.semibold))
                Text(span.dateRange())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: span)
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

    /// Robinhood-style period chips under the chart: 1D 1W 1M 1Y, with a filled pill that
    /// slides to the active span.
    private var spanSelector: some View {
        HStack(spacing: 0) {
            ForEach(TimeSpan.allCases) { option in
                Button {
                    span = option
                } label: {
                    Text(option.shortLabel)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(span == option ? Color(.systemBackground) : Color.secondary)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background {
                            if span == option {
                                Capsule()
                                    .fill(Color.primary)
                                    .matchedGeometryEffect(id: "spanPill", in: spanPillNamespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Time span: \(option.title)")
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: span)
    }

    /// The spending content, airy and card-free: full-bleed hero + chart, a hairline Repeat row,
    /// text tabs, and plain transaction rows separated by hairlines.
    private var spendingScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                TotalSpendingCard(
                    total: SpendingSummary.total(displayedCurrent),
                    previousTotal: SpendingSummary.total(comparablePrevious),
                    segments: SpendingSummary.categorySegments(displayedCurrent, buckets: periodBuckets),
                    bucketLabels: periodBuckets.map(\.label),
                    projection: projection,
                    budgetPerBucket: budgetPerBucket,
                    mode: $spendingMode
                )

                spanSelector

                recurringRow

                VStack(alignment: .leading, spacing: 4) {
                    tabRow
                    if tab == .recent {
                        recentRows
                    } else {
                        groupRows
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    /// Plain "Repeat" row between hairlines, linking to the recurring-payments list.
    private var recurringRow: some View {
        VStack(spacing: 0) {
            Divider()
            NavigationLink {
                RecurringPaymentsView()
            } label: {
                HStack(spacing: 8) {
                    Text("Repeat")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(recurringExpenses.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            Divider()
        }
    }

    /// Robinhood-style text tabs: the active one is bold primary, the rest stay secondary.
    private var tabRow: some View {
        HStack(spacing: 18) {
            ForEach(SpendingTab.allCases) { option in
                Button {
                    tab = option
                } label: {
                    Text(option.title)
                        .font(.subheadline.weight(tab == option ? .semibold : .regular))
                        .foregroundStyle(tab == option ? Color.primary : Color.secondary)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .animation(.easeInOut(duration: 0.15), value: tab)
    }

    /// Flat, date-ordered list of the period's transactions (the Recent tab).
    /// Honors the spending mode so ignored items don't appear in Variable mode.
    private var recentRows: some View {
        rowsList(displayedCurrent.isEmpty) {
            ForEach(Array(displayedCurrent.enumerated()), id: \.element.id) { index, expense in
                NavigationLink {
                    TransactionDetailView(expense: expense)
                } label: {
                    TransactionRow(expense: expense)
                }
                .buttonStyle(.plain)

                if index < displayedCurrent.count - 1 {
                    Divider().padding(.leading, 56)
                }
            }
        }
    }

    /// Grouped rows (By Merchant / By Category), each opening the group's transaction list.
    private var groupRows: some View {
        rowsList(groups.isEmpty) {
            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                NavigationLink {
                    GroupDetailView(grouping: grouping, key: group.key, interval: span.interval())
                } label: {
                    SpendingGroupRow(group: group, grouping: grouping)
                }
                .buttonStyle(.plain)

                if index < groups.count - 1 {
                    Divider().padding(.leading, 56)
                }
            }
        }
    }

    /// Plain rows on the page background (no card), or the empty message.
    @ViewBuilder
    private func rowsList<Rows: View>(_ isEmpty: Bool, @ViewBuilder rows: () -> Rows) -> some View {
        LazyVStack(spacing: 0) {
            if isEmpty {
                Text("No transactions in this period.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
            } else {
                rows()
            }
        }
    }

    /// The current-period expenses belonging to a group (mode-aware: excludes ignored in Variable).
    private func expenses(for group: GroupTotal) -> [Expense] {
        displayedCurrent.filter { expense in
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
