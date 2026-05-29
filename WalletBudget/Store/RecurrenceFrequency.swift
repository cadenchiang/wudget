import Foundation

/// How often a transaction repeats. `.none` means a one-time (non-recurring) purchase.
///
/// Stored on `Expense` as its `rawValue`. `nextOccurrence(from:after:)` computes the next due
/// date so the recurring list can show when a payment is expected.
enum RecurrenceFrequency: String, CaseIterable, Identifiable {
    case none
    case weekly
    case biweekly
    case monthly
    case everyTwoMonths
    case quarterly
    case yearly

    var id: String { rawValue }

    /// Human-readable label shown in pickers and rows.
    var label: String {
        switch self {
        case .none: return "Never"
        case .weekly: return "Weekly"
        case .biweekly: return "Every 2 Weeks"
        case .monthly: return "Monthly"
        case .everyTwoMonths: return "Every 2 Months"
        case .quarterly: return "Every 3 Months"
        case .yearly: return "Yearly"
        }
    }

    /// The calendar step for one cycle, or `nil` for `.none`.
    var step: (component: Calendar.Component, value: Int)? {
        switch self {
        case .none: return nil
        case .weekly: return (.day, 7)
        case .biweekly: return (.day, 14)
        case .monthly: return (.month, 1)
        case .everyTwoMonths: return (.month, 2)
        case .quarterly: return (.month, 3)
        case .yearly: return (.year, 1)
        }
    }

    /// The next occurrence strictly after `now`, advancing from `start` by whole cycles.
    /// - Parameters:
    ///   - start: The first/original payment date.
    ///   - now: The reference "current" date. Defaults to `Date()`.
    ///   - calendar: Calendar used to add cycles. Defaults to `.current`.
    /// - Returns: The next due date after `now`, or `nil` for `.none` or if it can't be computed.
    func nextOccurrence(from start: Date, after now: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard let step else { return nil }
        var date = start
        var iterations = 0
        while date <= now {
            guard let next = calendar.date(byAdding: step.component, value: step.value, to: date) else { return nil }
            date = next
            iterations += 1
            if iterations > 10_000 { return nil } // safety against pathological inputs
        }
        return date
    }
}
