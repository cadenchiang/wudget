import Foundation

/// A selectable time window for the spending view, in the Robinhood lineup:
/// 1D, 1W, 1M, 3M (trailing calendar quarter), YTD, 1Y, and All time.
///
/// All date math takes its inputs explicitly (`now`, `calendar`) so it is deterministic
/// and unit testable. `.all` has no bounds: `interval()` and `previousInterval()` are `nil`,
/// which downstream code treats as "no filter" / "no comparison".
enum TimeSpan: String, CaseIterable, Identifiable {
    case today
    case week
    case month
    case threeMonths
    case yearToDate
    case year
    case all

    var id: String { rawValue }

    /// Full label (pickers, accessibility).
    var title: String {
        switch self {
        case .today: return "Today"
        case .week: return "Week"
        case .month: return "Month"
        case .threeMonths: return "3 Months"
        case .yearToDate: return "Year to Date"
        case .year: return "Year"
        case .all: return "All Time"
        }
    }

    /// Compact label for the chart's period chips (Robinhood-style "1D 1W 1M 3M YTD 1Y All").
    var shortLabel: String {
        switch self {
        case .today: return "1D"
        case .week: return "1W"
        case .month: return "1M"
        case .threeMonths: return "3M"
        case .yearToDate: return "YTD"
        case .year: return "1Y"
        case .all: return "All"
        }
    }

    /// The single calendar component for the simple spans (nil for composite/unbounded spans).
    private var component: Calendar.Component? {
        switch self {
        case .today: return .day
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        case .threeMonths, .yearToDate, .all: return nil
        }
    }

    /// The date window for the span containing `now`.
    ///
    /// 3M covers the current calendar month and the two before it; YTD covers the start of the
    /// year through `now`. `.all` returns `nil` (unbounded).
    /// - Returns: The bounding `DateInterval`, or `nil` when unbounded/uncomputable.
    func interval(now: Date = Date(), calendar: Calendar = .current) -> DateInterval? {
        switch self {
        case .today, .week, .month, .year:
            guard let component else { return nil }
            return calendar.dateInterval(of: component, for: now)
        case .threeMonths:
            guard let month = calendar.dateInterval(of: .month, for: now),
                  let start = calendar.date(byAdding: .month, value: -2, to: month.start) else { return nil }
            return DateInterval(start: start, end: month.end)
        case .yearToDate:
            guard let year = calendar.dateInterval(of: .year, for: now), now > year.start else { return nil }
            return DateInterval(start: year.start, end: now)
        case .all:
            return nil
        }
    }

    /// The date window for the span immediately before the one containing `now`.
    ///
    /// 3M → the previous three calendar months; YTD → the previous year's start through the same
    /// date a year ago. `.all` returns `nil` (nothing to compare against).
    /// - Returns: The previous period's `DateInterval`, or `nil` when unbounded/uncomputable.
    func previousInterval(now: Date = Date(), calendar: Calendar = .current) -> DateInterval? {
        switch self {
        case .today, .week, .month, .year:
            guard let component,
                  let previousDate = calendar.date(byAdding: component, value: -1, to: now) else { return nil }
            return calendar.dateInterval(of: component, for: previousDate)
        case .threeMonths:
            guard let current = interval(now: now, calendar: calendar),
                  let start = calendar.date(byAdding: .month, value: -3, to: current.start) else { return nil }
            return DateInterval(start: start, end: current.start)
        case .yearToDate:
            guard let lastYearNow = calendar.date(byAdding: .year, value: -1, to: now),
                  let lastYear = calendar.dateInterval(of: .year, for: lastYearNow),
                  lastYearNow > lastYear.start else { return nil }
            return DateInterval(start: lastYear.start, end: lastYearNow)
        case .all:
            return nil
        }
    }

    /// A readable subtitle for the current period.
    ///
    /// Examples: week → "May 24 – 30", month → "May", 3M → "Mar – May", YTD → "Jan 1 – Jun 4",
    /// year → "2026", all → "All time".
    func dateRange(now: Date = Date(), calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        switch self {
        case .today:
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: now)
        case .week:
            guard let interval = interval(now: now, calendar: calendar) else { return "" }
            formatter.dateFormat = "MMM d"
            let start = formatter.string(from: interval.start)
            formatter.dateFormat = "d"
            return "\(start) – \(formatter.string(from: interval.end.addingTimeInterval(-1)))"
        case .month:
            formatter.dateFormat = "MMMM"
            return formatter.string(from: now)
        case .threeMonths:
            guard let interval = interval(now: now, calendar: calendar) else { return "" }
            formatter.dateFormat = "MMM"
            let start = formatter.string(from: interval.start)
            return "\(start) – \(formatter.string(from: now))"
        case .yearToDate:
            formatter.dateFormat = "MMM d"
            guard let interval = interval(now: now, calendar: calendar) else { return "" }
            let start = formatter.string(from: interval.start)
            return "\(start) – \(formatter.string(from: now))"
        case .year:
            guard let interval = interval(now: now, calendar: calendar) else { return "" }
            formatter.dateFormat = "yyyy"
            return formatter.string(from: interval.start)
        case .all:
            return "All time"
        }
    }
}
