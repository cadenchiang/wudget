import Foundation

/// A selectable time window for the spending view: a calendar week, month, or year.
///
/// All date math takes its inputs explicitly (`now`, `calendar`) so it is deterministic
/// and unit testable.
enum TimeSpan: String, CaseIterable, Identifiable {
    case today
    case week
    case month
    case year

    var id: String { rawValue }

    /// Label shown in the segmented control.
    var title: String {
        switch self {
        case .today: return "Today"
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }

    /// The calendar component this span spans.
    private var component: Calendar.Component {
        switch self {
        case .today: return .day
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }

    /// The date window for the span containing `now`.
    /// - Returns: The bounding `DateInterval`, or `nil` if it can't be computed.
    func interval(now: Date = Date(), calendar: Calendar = .current) -> DateInterval? {
        calendar.dateInterval(of: component, for: now)
    }

    /// The date window for the span immediately before the one containing `now`.
    /// - Returns: The previous period's `DateInterval`, or `nil` if it can't be computed.
    func previousInterval(now: Date = Date(), calendar: Calendar = .current) -> DateInterval? {
        guard let previousDate = calendar.date(byAdding: component, value: -1, to: now) else { return nil }
        return calendar.dateInterval(of: component, for: previousDate)
    }

    /// A readable subtitle for the current period.
    ///
    /// Examples: week → "May 24 – 30", month → "May", year → "2026".
    func dateRange(now: Date = Date(), calendar: Calendar = .current) -> String {
        guard let interval = interval(now: now, calendar: calendar) else { return "" }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        switch self {
        case .today:
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: now)
        case .week:
            formatter.dateFormat = "MMM d"
            let start = formatter.string(from: interval.start)
            formatter.dateFormat = "d"
            return "\(start) – \(formatter.string(from: interval.end.addingTimeInterval(-1)))"
        case .month:
            formatter.dateFormat = "MMMM"
            return formatter.string(from: now)
        case .year:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: interval.start)
        }
    }
}
