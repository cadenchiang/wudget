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
    @Environment(\.modelContext) private var context
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
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

    var body: some View {
        NavigationStack {
            spendingList
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

    /// The spending content as a List. The top cards keep their look via clear rows; the Recent
    /// rows support native swipe-to-delete, while grouped rows do not.
    private var spendingList: some View {
        List {
            Section {
                TotalSpendingCard(
                    total: SpendingSummary.total(currentExpenses),
                    previousTotal: SpendingSummary.total(previousExpenses),
                    segments: SpendingSummary.categorySegments(currentExpenses, buckets: periodBuckets),
                    bucketLabels: periodBuckets.map(\.label)
                )
                .clearRow(top: 8)

                recurringCard.clearRow()

                Picker("View", selection: $tab) {
                    ForEach(SpendingTab.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .clearRow()
            }

            Section {
                if tab == .recent {
                    recentRows
                } else {
                    groupRows
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    /// Flat, date-ordered transaction rows with swipe-to-delete (the Recent tab).
    @ViewBuilder
    private var recentRows: some View {
        if currentExpenses.isEmpty {
            emptyRow
        } else {
            ForEach(currentExpenses) { expense in
                NavigationLink {
                    TransactionDetailView(expense: expense)
                } label: {
                    ExpenseRow(expense: expense)
                }
            }
            .onDelete(perform: deleteRecent)
        }
    }

    /// Grouped rows (By Merchant / By Category), each opening the group's transaction list.
    @ViewBuilder
    private var groupRows: some View {
        if groups.isEmpty {
            emptyRow
        } else {
            ForEach(groups) { group in
                NavigationLink {
                    GroupDetailView(grouping: grouping, key: group.key, interval: span.interval())
                } label: {
                    SpendingGroupRow(group: group, grouping: grouping)
                }
            }
        }
    }

    /// Deletes recent transactions at the given offsets and saves.
    private func deleteRecent(at offsets: IndexSet) {
        Haptics.tap(.rigid)
        for expense in offsets.map({ currentExpenses[$0] }) {
            context.delete(expense)
        }
        do {
            try context.save()
        } catch {
            Log.ui.error("Failed to delete transaction(s): \(error.localizedDescription, privacy: .public)")
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

    private var emptyRow: some View {
        Text("No transactions in this period.")
            .foregroundStyle(.secondary)
    }
}

private extension View {
    /// Renders this view as a full-bleed, background-less list row so it keeps its own card look.
    func clearRow(top: CGFloat = 0) -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: top, leading: 16, bottom: 8, trailing: 16))
    }
}

#Preview {
    SpendingView()
        .modelContainer(for: Expense.self, inMemory: true)
}
