import Foundation
import SwiftData
import WidgetKit

/// Builds the widget snapshot from the current data and tells WidgetKit to reload.
///
/// Called when the app launches/foregrounds and after a Wallet import, so the home-screen widget
/// stays in sync with this month's spending.
enum WidgetUpdater {
    @MainActor
    static func refresh(context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<Expense>(sortBy: [SortDescriptor(\Expense.date, order: .reverse)]))) ?? []
        guard let month = TimeSpan.month.interval() else { return }

        let monthExpenses = SpendingSummary.filter(all, in: month)
        let spent = SpendingSummary.total(monthExpenses)
        // "Everyday Spending": the same period total minus fixed costs the user marked as
        // excluded, so the widget's Everyday scope matches the app's Variable mode.
        let variableSpent = SpendingSummary.total(monthExpenses.filter { !$0.excludedFromBudget })
        let budget = UserDefaults.standard.double(forKey: ProfileKeys.monthlyBudget)
        let stored = UserDefaults.standard.string(forKey: ProfileKeys.currencyCode)
        let code = (stored?.isEmpty == false ? stored : nil) ?? Locale.current.currency?.identifier ?? "USD"

        let recent = all.prefix(3).map {
            WidgetTxn(merchant: $0.merchant.isEmpty ? "Unknown" : $0.merchant, amount: $0.amount, category: $0.category)
        }

        let snapshot = WidgetSnapshot(
            monthSpent: spent,
            monthVariableSpent: variableSpent,
            monthBudget: budget,
            periodLabel: TimeSpan.month.dateRange(),
            currencyCode: code,
            recent: Array(recent)
        )
        WidgetStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
