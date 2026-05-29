import Foundation

/// One bar position on the spending chart: a labeled sub-interval of the selected period.
struct PeriodBucket: Identifiable {
    /// Identity is the (unique) label.
    var id: String { label }
    /// Axis label (e.g. "Mon", "1-7", "Jan").
    let label: String
    /// The date range this bucket covers.
    let interval: DateInterval
}

/// Splits a `TimeSpan` into the ordered buckets shown along the chart's x-axis:
/// days for a week, ~weekly day-ranges for a month, and months for a year.
///
/// Labels are chosen to be unique within a period so chart x-categories don't collide.
enum PeriodBucketizer {
    /// Produces the ordered buckets for a span around `now`.
    /// - Parameters:
    ///   - span: The selected time span.
    ///   - now: Reference date inside the period.
    ///   - calendar: Calendar used for all boundaries.
    /// - Returns: Ordered buckets, or `[]` if the period interval can't be computed.
    static func buckets(for span: TimeSpan, now: Date = Date(), calendar: Calendar = .current) -> [PeriodBucket] {
        switch span {
        case .week:
            return weekBuckets(now: now, calendar: calendar)
        case .month:
            return monthBuckets(now: now, calendar: calendar)
        case .year:
            return yearBuckets(now: now, calendar: calendar)
        }
    }

    /// Seven daily buckets labeled by short weekday name (Sun…Sat).
    private static func weekBuckets(now: Date, calendar: Calendar) -> [PeriodBucket] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
        var buckets: [PeriodBucket] = []
        for offset in 0..<7 {
            guard let start = calendar.date(byAdding: .day, value: offset, to: week.start),
                  let end = calendar.date(byAdding: .day, value: offset + 1, to: week.start) else { continue }
            let weekday = calendar.component(.weekday, from: start)
            let label = calendar.shortWeekdaySymbols[(weekday - 1) % 7]
            buckets.append(PeriodBucket(label: label, interval: DateInterval(start: start, end: end)))
        }
        return buckets
    }

    /// Day-of-month ranges (1-7, 8-14, 15-21, 22-28, 29-end).
    private static func monthBuckets(now: Date, calendar: Calendar) -> [PeriodBucket] {
        guard let month = calendar.dateInterval(of: .month, for: now),
              let dayRange = calendar.range(of: .day, in: .month, for: now) else { return [] }
        let lastDay = dayRange.count
        let starts = [1, 8, 15, 22, 29]
        var buckets: [PeriodBucket] = []
        for (index, firstDay) in starts.enumerated() where firstDay <= lastDay {
            let lastInBucket = index + 1 < starts.count ? min(starts[index + 1] - 1, lastDay) : lastDay
            guard let start = calendar.date(byAdding: .day, value: firstDay - 1, to: month.start),
                  let end = calendar.date(byAdding: .day, value: lastInBucket, to: month.start) else { continue }
            buckets.append(PeriodBucket(label: "\(firstDay)-\(lastInBucket)", interval: DateInterval(start: start, end: end)))
        }
        return buckets
    }

    /// Twelve monthly buckets labeled by short month name (Jan…Dec).
    private static func yearBuckets(now: Date, calendar: Calendar) -> [PeriodBucket] {
        guard let year = calendar.dateInterval(of: .year, for: now) else { return [] }
        var buckets: [PeriodBucket] = []
        for offset in 0..<12 {
            guard let start = calendar.date(byAdding: .month, value: offset, to: year.start),
                  let end = calendar.date(byAdding: .month, value: offset + 1, to: year.start) else { continue }
            let monthIndex = calendar.component(.month, from: start) - 1
            buckets.append(PeriodBucket(label: calendar.shortMonthSymbols[monthIndex], interval: DateInterval(start: start, end: end)))
        }
        return buckets
    }
}
