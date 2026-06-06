import Foundation
import SwiftData

/// Builders for the calendar-scheduled reminders. Each reads the user's data/settings on the main
/// actor and schedules concrete notifications via `NotificationManager`'s low-level helpers.
extension NotificationManager {
    /// One reminder per recurring expense whose next charge is still upcoming.
    @MainActor
    func scheduleCharges(_ expenses: [Expense]) {
        let leadDays = max(0, UserDefaults.standard.object(forKey: NotificationKeys.leadDays) as? Int ?? 1)
        let calendar = Calendar.current
        let now = Date()

        for expense in expenses where expense.recurrence != .none {
            guard let next = expense.recurrence.nextOccurrence(from: expense.date, after: now),
                  let lead = calendar.date(byAdding: .day, value: -leadDays, to: next),
                  let fireDate = at9am(lead) else { continue }
            let merchant = expense.merchant.isEmpty ? "A subscription" : expense.merchant
            let when = leadDays == 0 ? "today" : (leadDays == 1 ? "tomorrow" : "in \(leadDays) days")
            let onCard = expense.card.isEmpty ? "" : " to your \(expense.card)"
            scheduleCalendar(
                id: NotificationID.chargePrefix + expense.id.uuidString,
                title: "Upcoming charge",
                body: "Heads up: \(merchant) will charge \(expense.amount.asCurrency())\(onCard) \(when).",
                at: fireDate
            )
        }
    }

    /// A Monday-morning summary of the last 7 days of spending.
    @MainActor
    func scheduleWeeklySummary(_ expenses: [Expense]) {
        guard let fireDate = nextWeekday(2) else { return } // 2 = Monday
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)
        let recent = expenses.filter { ($0.date >= (weekAgo ?? now)) && $0.date <= now }
        let total = SpendingSummary.total(recent)
        scheduleCalendar(
            id: NotificationID.weekly,
            title: "Your week in spending",
            body: "You spent \(total.asCurrency()) over the last 7 days. Tap to review.",
            at: fireDate
        )
    }

    /// A start-of-month reminder that the budget has reset.
    @MainActor
    func scheduleMonthlyReset() {
        guard let fireDate = firstOfNextMonth() else { return }
        let budget = UserDefaults.standard.double(forKey: ProfileKeys.monthlyBudget)
        let body = budget > 0
            ? "New month! Your budget resets — you have \(budget.asCurrency()) to spend."
            : "New month! A fresh start for your spending."
        scheduleCalendar(id: NotificationID.monthlyReset, title: "Budget reset", body: body, at: fireDate)
    }

    /// A monthly nudge toward the savings goal, with the per-month amount needed to reach it.
    @MainActor
    func scheduleSavingsReminder() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: ProfileKeys.hasSavingsGoal) else { return }
        let target = defaults.double(forKey: ProfileKeys.savingsAmount)
        guard target > 0, let fireDate = firstOfNextMonth() else { return }

        let name = defaults.string(forKey: ProfileKeys.savingsName) ?? ""
        let goalDate = Date(timeIntervalSince1970: defaults.double(forKey: ProfileKeys.savingsDate))
        let months = max(1, Calendar.current.dateComponents([.month], from: Date(), to: goalDate).month ?? 1)
        let perMonth = target / Double(months)
        let forWhat = name.isEmpty ? "your goal" : "\"\(name)\""
        scheduleCalendar(
            id: NotificationID.savings,
            title: "Savings goal",
            body: "Set aside \(perMonth.asCurrency()) this month to stay on track for \(forWhat).",
            at: fireDate
        )
    }

    /// A monthly review of recurring payments (count + combined amount).
    @MainActor
    func scheduleSubscriptionReview(_ expenses: [Expense]) {
        let recurring = expenses.filter { $0.recurrence != .none }
        guard !recurring.isEmpty, let fireDate = firstOfNextMonth() else { return }
        let total = recurring.reduce(0) { $0 + $1.amount }
        let countWord = "\(recurring.count) recurring payment\(recurring.count == 1 ? "" : "s")"
        scheduleCalendar(
            id: NotificationID.subscription,
            title: "Subscription check",
            body: "You have \(countWord) totaling about \(total.asCurrency()). Tap to review.",
            at: fireDate
        )
    }

    /// One notification each morning with what's safe to spend that day: the
    /// month's remaining budget spread over its remaining days. Amounts are
    /// computed at schedule time and rebuilt on every app open, so the nearest
    /// mornings are always the most accurate.
    @MainActor
    func scheduleDailyAllowance(_ expenses: [Expense]) {
        let budget = UserDefaults.standard.double(forKey: ProfileKeys.monthlyBudget)
        guard budget > 0, let month = TimeSpan.month.interval() else { return }
        let spent = SpendingSummary.total(SpendingSummary.filter(expenses, in: month))
        let remaining = budget - spent
        let calendar = Calendar.current

        for offset in 1...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: Date()),
                  day < month.end,
                  let fireDate = at9am(day) else { continue }
            let daysLeft = max(1, calendar.dateComponents(
                [.day], from: calendar.startOfDay(for: day), to: month.end).day ?? 1)
            let allowance = Self.dailyAllowance(remaining: remaining, daysLeft: daysLeft)
            let body = remaining > 0
                ? "You can spend \(allowance.asCurrency()) today and stay on budget (\(remaining.asCurrency()) left this month)."
                : "You're \((-remaining).asCurrency()) over budget this month. A no-spend day keeps it from growing."
            scheduleCalendar(id: NotificationID.dailyAllowancePrefix + "\(offset)",
                             title: "Today's budget",
                             body: body,
                             at: fireDate)
        }
    }

    // MARK: - Date helpers

    /// The given day at 9:00am local time.
    private func at9am(_ day: Date) -> Date? {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: day)
        comps.hour = 9
        return Calendar.current.date(from: comps)
    }

    /// The next occurrence of `weekday` (1 = Sunday … 7 = Saturday) at 9am, strictly in the future.
    private func nextWeekday(_ weekday: Int) -> Date? {
        var comps = DateComponents()
        comps.weekday = weekday
        comps.hour = 9
        return Calendar.current.nextDate(after: Date(), matching: comps, matchingPolicy: .nextTime)
    }

    /// The first day of next month at 9am.
    private func firstOfNextMonth() -> Date? {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.dateInterval(of: .month, for: Date())?.end else { return nil }
        var comps = calendar.dateComponents([.year, .month, .day], from: startOfMonth)
        comps.hour = 9
        return calendar.date(from: comps)
    }
}
