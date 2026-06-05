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

/// Carries each list chip's bounds so the selector can slide one persistent pill between them.
private struct TabChipBoundsKey: PreferenceKey {
    static var defaultValue: [SpendingTab: Anchor<CGRect>] = [:]
    static func reduce(value: inout [SpendingTab: Anchor<CGRect>], nextValue: () -> [SpendingTab: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Main screen: a Week/Month/Year selector, a total-spending card with a bar chart, a
/// Recent / By Merchant / By Category selector, and the matching rows below.
struct SpendingView: View {
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @AppStorage("budget.monthly") private var monthlyBudget = 0.0
    @AppStorage("budget.enabled") private var budgetEnabled = true
    @State private var span: TimeSpan = .month
    @State private var tab: SpendingTab = .recent
    @State private var showingAdd = false
    /// Expenses within the selected period (already date-descending from the query).
    private var currentExpenses: [Expense] {
        SpendingSummary.filter(expenses, in: span.interval())
    }

    /// Expenses within the previous period (for deltas/comparison).
    private var previousExpenses: [Expense] {
        SpendingSummary.filter(expenses, in: span.previousInterval())
    }

    /// Current-period expenses (everything shows; fixed costs raise the budget line instead
    /// of being filtered out).
    private var displayedCurrent: [Expense] {
        currentExpenses
    }

    /// Previous-period expenses.
    private var displayedPrevious: [Expense] {
        previousExpenses
    }

    /// Fixed costs in the current period (transactions marked "ignore"): rather than hiding
    /// them, they push the budget ceiling up, since that money was committed regardless.
    private var fixedSpent: Double {
        SpendingSummary.total(currentExpenses.filter { $0.excludedFromBudget })
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

    /// The chart's x-domain: the selected period, or first-transaction-to-now for All time.
    private var chartDomain: ClosedRange<Date> {
        let now = Date()
        if let interval = span.interval(), interval.start < interval.end {
            return interval.start...interval.end
        }
        // All time is unbounded: span from the earliest transaction (or a month back) to now.
        let earliest = expenses.last?.date ?? Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        return min(earliest, now)...now
    }

    /// The period's transactions as chart entries (exact timestamps drive the line).
    private var chartEntries: [SpendingChartEntry] {
        displayedCurrent.map { SpendingChartEntry(date: $0.date, amount: $0.amount, category: $0.category) }
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
        let base: Double?
        switch span {
        case .today: base = monthlyBudget / 30.4
        case .week: base = monthlyBudget * 7.0 / 30.4
        case .month: base = monthlyBudget
        case .threeMonths: base = monthlyBudget * 3.0
        case .yearToDate: base = monthlyBudget * Double(Calendar.current.component(.month, from: Date()))
        case .year: base = monthlyBudget * 12.0
        case .all: base = nil // no bounded period to budget against
        }
        // Fixed costs lift the ceiling: the line tracks ALL spending, so the budget allows
        // the committed fixed amount on top of the everyday budget.
        return base.map { $0 + fixedSpent }
    }

    /// Period noun used in the prediction copy.
    private var periodNoun: String {
        switch span {
        case .today: return "day"
        case .week: return "week"
        case .month: return "month"
        case .threeMonths: return "quarter"
        case .yearToDate, .year: return "year"
        case .all: return "period"
        }
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
        }
    }

    /// Transparent top bar: the time-span dropdown with the selected period's date range beneath
    /// it, add button trailing. (Mode selection lives in the chip slider under the chart.)
    private var topBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 1) {
                spanMenu
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

    /// The time-span dropdown shown as the screen title (Today … All Time).
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

    /// The spending content, airy and card-free: full-bleed hero + chart, a hairline Repeat row,
    /// the list dropdown, and plain transaction rows separated by hairlines.
    private var spendingScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TotalSpendingCard(
                    total: SpendingSummary.total(displayedCurrent),
                    previousTotal: SpendingSummary.total(comparablePrevious),
                    entries: chartEntries,
                    domain: chartDomain,
                    buckets: PeriodBucketizer.buckets(for: span),
                    projection: projection,
                    periodBudget: periodBudget
                )

                recurringRow

                budgetBlurbCard

                VStack(alignment: .leading, spacing: 4) {
                    tabSelector
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

    /// Plain "Repeat" row above a hairline, linking to the recurring-payments list.
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
        }
    }

    /// The per-day allowance as a quiet card under the Repeat row: the piggy glyph beside the
    /// "you can spend X a day" sentence on subtle Apple gray. Hidden when no budget is set.
    @ViewBuilder
    private var budgetBlurbCard: some View {
        if let sentence = projection?.perDaySentence {
            HStack(spacing: 14) {
                Image("welcomePiggy")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .foregroundStyle(.primary)
                sentence
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    /// The list selector as chips: Recent / By Merchant / By Category. One persistent pill
    /// slides between chips (positioned via anchor preferences rather than
    /// matchedGeometryEffect, which stutters when the heavy row list swaps in the same frame).
    private var tabSelector: some View {
        HStack(spacing: 4) {
            ForEach(SpendingTab.allCases) { option in
                Button {
                    tab = option
                } label: {
                    Text(option.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tab == option ? Color(.systemBackground) : Color.secondary)
                        .animation(.easeInOut(duration: 0.15), value: tab)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 6)
                        .contentShape(Capsule())
                        .anchorPreference(key: TabChipBoundsKey.self, value: .bounds) { [option: $0] }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("List: \(option.title)")
            }
            Spacer(minLength: 0)
        }
        .backgroundPreferenceValue(TabChipBoundsKey.self) { anchors in
            GeometryReader { geo in
                if let anchor = anchors[tab] {
                    let frame = geo[anchor]
                    Capsule()
                        .fill(Color.primary)
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: frame)
                }
            }
        }
        .padding(.vertical, 6)
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
