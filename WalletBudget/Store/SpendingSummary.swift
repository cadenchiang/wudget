import Foundation

/// A category paired with its summed spend, ready for display in a list/chart.
struct CategoryTotal: Identifiable, Equatable {
    /// Identity is the category name (categories are unique within a summary).
    var id: String { category }
    let category: String
    let total: Double
}

/// How spending rows are grouped on the spending screen.
enum SpendingGrouping: String, CaseIterable, Identifiable, Hashable {
    case merchant
    case category

    var id: String { rawValue }

    /// Label shown in the segmented toggle.
    var title: String {
        switch self {
        case .merchant: return "By Merchant"
        case .category: return "By Category"
        }
    }
}

/// A grouped spend (by category or merchant) with its transaction count and the change
/// versus the previous period.
struct GroupTotal: Identifiable, Equatable {
    /// Identity is the group key (unique within a grouping).
    var id: String { key }
    /// Category name or merchant name.
    let key: String
    /// Total spent in this group during the current period.
    let total: Double
    /// Number of transactions in this group during the current period.
    let count: Int
    /// Total spent in this group during the previous period (0 if none).
    let previousTotal: Double

    /// Change versus the previous period (positive = spent more).
    var delta: Double { total - previousTotal }
    /// Whether a previous-period comparison is meaningful.
    var hasComparison: Bool { previousTotal > 0 }
}

/// One bar's value: a bucket label paired with its summed spend.
struct BucketTotal: Identifiable, Equatable {
    var id: String { label }
    let label: String
    let total: Double
}

/// One stacked segment: spend for a single category within a single time bucket.
struct CategorySegment: Identifiable, Equatable {
    var id: String { "\(bucketLabel)|\(category)" }
    let bucketLabel: String
    let category: String
    let total: Double
}

/// Pure aggregation helpers over a collection of `Expense` values.
///
/// All functions are side-effect free and take their inputs explicitly (including the
/// `Calendar`) so the month-bucketing logic is deterministic and unit testable.
enum SpendingSummary {
    /// Sums the `amount` of every expense.
    /// - Parameter expenses: Expenses to total.
    /// - Returns: The summed amount. `0` for an empty array.
    static func total(_ expenses: [Expense]) -> Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    /// Filters expenses to those falling within an optional date interval.
    /// - Parameters:
    ///   - expenses: Expenses to filter.
    ///   - interval: The bounding interval, or `nil` to apply no bound (returns all).
    /// - Returns: Expenses whose `date` is contained in `interval`, or all expenses when `interval` is `nil`.
    static func filter(_ expenses: [Expense], in interval: DateInterval?) -> [Expense] {
        guard let interval else { return expenses }
        return expenses.filter { interval.contains($0.date) }
    }

    /// Filters expenses to those falling within the calendar month of a reference date.
    /// - Parameters:
    ///   - date: Any date inside the target month.
    ///   - expenses: Expenses to filter.
    ///   - calendar: Calendar used to compute the month interval. Defaults to `.current`.
    /// - Returns: Expenses whose `date` is within the month, or `[]` if the interval can't be computed.
    static func inMonth(of date: Date, expenses: [Expense], calendar: Calendar = .current) -> [Expense] {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return [] }
        return expenses.filter { interval.contains($0.date) }
    }

    /// Groups expenses by category and sums each group.
    /// - Parameter expenses: Expenses to group.
    /// - Returns: One `CategoryTotal` per category, sorted by total descending (ties broken by name).
    static func byCategory(_ expenses: [Expense]) -> [CategoryTotal] {
        var sums: [String: Double] = [:]
        for expense in expenses {
            sums[expense.category, default: 0] += expense.amount
        }
        return sums
            .map { CategoryTotal(category: $0.key, total: $0.value) }
            .sorted { lhs, rhs in
                lhs.total == rhs.total ? lhs.category < rhs.category : lhs.total > rhs.total
            }
    }

    /// Groups current expenses by category or merchant, attaching transaction counts and the
    /// matching previous-period total for each group.
    /// - Parameters:
    ///   - current: Expenses in the current period.
    ///   - previous: Expenses in the previous period (used for the delta).
    ///   - grouping: Whether to group by category or merchant.
    /// - Returns: One `GroupTotal` per group, sorted by current total descending (ties by name).
    static func groups(current: [Expense], previous: [Expense], by grouping: SpendingGrouping) -> [GroupTotal] {
        func key(_ expense: Expense) -> String {
            switch grouping {
            case .category: return expense.category
            case .merchant: return expense.merchant.isEmpty ? "Unknown" : expense.merchant
            }
        }

        var totals: [String: Double] = [:]
        var counts: [String: Int] = [:]
        for expense in current {
            let k = key(expense)
            totals[k, default: 0] += expense.amount
            counts[k, default: 0] += 1
        }

        var previousTotals: [String: Double] = [:]
        for expense in previous {
            previousTotals[key(expense), default: 0] += expense.amount
        }

        return totals
            .map { GroupTotal(key: $0.key, total: $0.value, count: counts[$0.key] ?? 0, previousTotal: previousTotals[$0.key] ?? 0) }
            .sorted { lhs, rhs in
                lhs.total == rhs.total ? lhs.key < rhs.key : lhs.total > rhs.total
            }
    }

    /// Sums spend into the given chart buckets.
    /// - Parameters:
    ///   - expenses: Expenses to bucket (already filtered to the period).
    ///   - buckets: The ordered period buckets.
    /// - Returns: One `BucketTotal` per bucket, in bucket order.
    static func bucketTotals(_ expenses: [Expense], buckets: [PeriodBucket]) -> [BucketTotal] {
        buckets.map { bucket in
            let sum = expenses
                .filter { bucket.interval.contains($0.date) }
                .reduce(0) { $0 + $1.amount }
            return BucketTotal(label: bucket.label, total: sum)
        }
    }

    /// Splits each bucket's spend into per-category segments for a stacked bar chart.
    /// - Parameters:
    ///   - expenses: Expenses to bucket (already filtered to the period).
    ///   - buckets: The ordered period buckets.
    /// - Returns: Segments with total > 0, ordered by bucket then by category total descending.
    static func categorySegments(_ expenses: [Expense], buckets: [PeriodBucket]) -> [CategorySegment] {
        var segments: [CategorySegment] = []
        for bucket in buckets {
            var sums: [String: Double] = [:]
            for expense in expenses where bucket.interval.contains(expense.date) {
                sums[expense.category, default: 0] += expense.amount
            }
            let ordered = sums
                .filter { $0.value > 0 }
                .sorted { $0.value > $1.value }
            for entry in ordered {
                segments.append(CategorySegment(bucketLabel: bucket.label, category: entry.key, total: entry.value))
            }
        }
        return segments
    }
}
