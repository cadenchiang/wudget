import Foundation
import SwiftData
import UserNotifications

/// `UserDefaults`/`AppStorage` keys for notification preferences.
enum NotificationKeys {
    /// Master switch. When off, nothing is scheduled or delivered.
    static let enabled = "notify.enabled"
    /// Remind before recurring charges.
    static let upcomingCharges = "notify.upcomingCharges"
    /// Days before a charge to fire the reminder (0 = same day).
    static let leadDays = "notify.leadDays"
    /// Alert at 80% and 100% of the monthly budget.
    static let budgetAlerts = "notify.budgetAlerts"
    /// Weekly spending summary.
    static let weeklySummary = "notify.weeklySummary"
    /// Start-of-month budget reset reminder.
    static let monthlyReset = "notify.monthlyReset"
    /// Monthly savings-goal nudge.
    static let savingsReminder = "notify.savingsReminder"
    /// Monthly subscription review.
    static let subscriptionReview = "notify.subscriptionReview"
    /// Each morning: how much can be spent today given the remaining budget.
    static let dailyAllowance = "notify.dailyAllowance"
    /// Alert on a single large purchase.
    static let largePurchase = "notify.largePurchase"
    /// Amount at/above which a purchase counts as "large".
    static let largePurchaseThreshold = "notify.largeThreshold"
    /// Internal: the latest budget-alert level fired this month ("2026-05:80"), for de-duping.
    static let budgetAlertedStamp = "notify.budgetAlertedStamp"

    /// Reads a sub-toggle, defaulting to `on` when never set (so enabling notifications turns the
    /// individual reminders on by default).
    static func isOn(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }
}

/// Stable identifiers for the managed notifications.
enum NotificationID {
    static let chargePrefix = "charge."
    static let weekly = "weekly.summary"
    static let monthlyReset = "monthly.reset"
    static let savings = "savings.reminder"
    static let subscription = "subscription.review"
    static let budgetPrefix = "budget."
    static let largePrefix = "large."
    static let dailyAllowancePrefix = "daily.allowance."
}

/// Manages all on-device notifications: authorization, the calendar-scheduled reminders
/// (charges, weekly/monthly summaries, savings, subscriptions), and event-driven alerts
/// (budget thresholds, large purchases). There is no server; everything is local.
@Observable
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    /// Current system authorization status (refreshed via `refreshAuthorization`).
    private(set) var authorization: UNAuthorizationStatus = .notDetermined

    let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
    }

    // MARK: - Authorization

    /// Reads the current system authorization status into `authorization`.
    func refreshAuthorization() {
        center.getNotificationSettings { settings in
            Task { @MainActor in self.authorization = settings.authorizationStatus }
        }
    }

    /// Requests notification permission and reports whether it was granted (on the main actor).
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                Log.ui.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
            }
            Task { @MainActor in
                self.refreshAuthorization()
                completion(granted)
            }
        }
    }

    /// Shows banners/sounds even while the app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }

    // MARK: - Scheduling entry points

    /// Clears and rebuilds every calendar-scheduled reminder from the user's data and settings.
    /// No-ops (and clears) when notifications are disabled.
    /// - Parameter context: Main-actor model context used to read expenses.
    @MainActor
    func refreshAll(context: ModelContext) {
        center.removeAllPendingNotificationRequests()
        guard UserDefaults.standard.bool(forKey: NotificationKeys.enabled) else { return }

        let all = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
        if NotificationKeys.isOn(NotificationKeys.upcomingCharges) { scheduleCharges(all) }
        if NotificationKeys.isOn(NotificationKeys.weeklySummary) { scheduleWeeklySummary(all) }
        if NotificationKeys.isOn(NotificationKeys.monthlyReset) { scheduleMonthlyReset() }
        if NotificationKeys.isOn(NotificationKeys.savingsReminder) { scheduleSavingsReminder() }
        if NotificationKeys.isOn(NotificationKeys.subscriptionReview) { scheduleSubscriptionReview(all) }
        if NotificationKeys.isOn(NotificationKeys.dailyAllowance) { scheduleDailyAllowance(all) }
    }

    /// Today's safe-to-spend amount: the remaining budget spread evenly over the
    /// month's remaining days. Never negative; 0 when over budget or no days left.
    /// - Parameters:
    ///   - remaining: budget minus what's been spent this month (may be negative).
    ///   - daysLeft: remaining days in the month including today (must be > 0).
    /// - Returns: the per-day allowance.
    static func dailyAllowance(remaining: Double, daysLeft: Int) -> Double {
        guard daysLeft > 0 else { return 0 }
        return max(0, remaining) / Double(daysLeft)
    }

    /// Checks current-month spend against the budget and fires an 80%/100% alert at most once each
    /// per month. Call when the app becomes active.
    /// - Parameter context: Main-actor model context used to read expenses.
    @MainActor
    func checkBudgetAlerts(context: ModelContext) {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: NotificationKeys.enabled),
              NotificationKeys.isOn(NotificationKeys.budgetAlerts) else { return }
        let budget = defaults.double(forKey: ProfileKeys.monthlyBudget)
        guard budget > 0, let interval = TimeSpan.month.interval() else { return }

        let all = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
        let spent = SpendingSummary.total(SpendingSummary.filter(all, in: interval))
        let fraction = spent / budget
        let monthKey = Self.monthKey(for: Date())
        let stamp = defaults.string(forKey: NotificationKeys.budgetAlertedStamp) ?? ""

        if fraction >= 1.0, stamp != "\(monthKey):100" {
            deliverNow(id: NotificationID.budgetPrefix + monthKey, title: "Over budget",
                       body: "You've spent \(spent.asCurrency()) of your \(budget.asCurrency()) budget this month.")
            defaults.set("\(monthKey):100", forKey: NotificationKeys.budgetAlertedStamp)
        } else if fraction >= 0.8, stamp != "\(monthKey):80", stamp != "\(monthKey):100" {
            deliverNow(id: NotificationID.budgetPrefix + monthKey, title: "Budget check-in",
                       body: "You've used \(Int((fraction * 100).rounded()))% of your \(budget.asCurrency()) monthly budget.")
            defaults.set("\(monthKey):80", forKey: NotificationKeys.budgetAlertedStamp)
        }
    }

    /// Delivers a one-off large-purchase alert when an imported charge meets the threshold.
    /// - Parameters:
    ///   - amount: The purchase amount.
    ///   - merchant: Merchant name.
    ///   - card: Card name (may be empty).
    func notifyLargePurchase(amount: Double, merchant: String, card: String) {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: NotificationKeys.enabled),
              NotificationKeys.isOn(NotificationKeys.largePurchase) else { return }
        let threshold = defaults.object(forKey: NotificationKeys.largePurchaseThreshold) as? Double ?? 100
        guard threshold > 0, amount >= threshold else { return }

        let who = merchant.isEmpty ? "a merchant" : merchant
        let onCard = card.isEmpty ? "" : " on your \(card)"
        deliverNow(id: NotificationID.largePrefix + UUID().uuidString,
                   title: "Large purchase",
                   body: "\(amount.asCurrency()) charged at \(who)\(onCard).")
    }

    /// Delivers a sample notification immediately so the user can see what alerts look like.
    func sendTestNotification() {
        deliverNow(id: "test." + UUID().uuidString,
                   title: "Test notification",
                   body: "This is how Budget will alert you. You're all set!")
    }

    // MARK: - Low-level helpers (used here and by the builders extension)

    /// Delivers a notification immediately.
    func deliverNow(id: String, title: String, body: String) {
        center.add(request(id: id, title: title, body: body, trigger: nil))
    }

    /// Schedules a one-off notification for an absolute date (ignored if in the past).
    func scheduleCalendar(id: String, title: String, body: String, at date: Date) {
        guard date > Date() else { return }
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(request(id: id, title: title, body: body, trigger: trigger))
    }

    /// Builds a notification request, logging add failures.
    private func request(id: String, title: String, body: String, trigger: UNNotificationTrigger?) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    /// "2026-05"-style month key used to de-dupe budget alerts.
    static func monthKey(for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)"
    }
}
