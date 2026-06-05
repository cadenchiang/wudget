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

/// Splits a `TimeSpan` into the ordered buckets shown along the chart's x-axis, fine-grained so
/// the cumulative line reads like a market chart: 3-hour slots for a day, days for a week and a
/// month, weeks for 3M/YTD, and months for a year / all time.
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
        case .today:
            return todayBuckets(now: now, calendar: calendar)
        case .week:
            return weekBuckets(now: now, calendar: calendar)
        case .month:
            guard let month = calendar.dateInterval(of: .month, for: now) else { return [] }
            return steppedBuckets(in: month, stepDays: 1, calendar: calendar)
        case .threeMonths:
            guard let interval = TimeSpan.threeMonths.interval(now: now, calendar: calendar) else { return [] }
            return steppedBuckets(in: interval, stepDays: 7, calendar: calendar)
        case .yearToDate:
            guard let interval = TimeSpan.yearToDate.interval(now: now, calendar: calendar) else { return [] }
            return steppedBuckets(in: interval, stepDays: 7, calendar: calendar)
        case .year:
            return yearBuckets(now: now, calendar: calendar)
        case .all:
            // All time is unbounded; the chart shows the trailing twelve months (totals upstream
            // still count everything).
            return trailingMonthBuckets(count: 12, now: now, calendar: calendar)
        }
    }

    /// The last `count` calendar months ending with the current month, labeled by short month
    /// name (unique for count ≤ 12).
    private static func trailingMonthBuckets(count: Int, now: Date, calendar: Calendar) -> [PeriodBucket] {
        guard count > 0, let currentMonth = calendar.dateInterval(of: .month, for: now) else { return [] }
        var buckets: [PeriodBucket] = []
        for offset in stride(from: count - 1, through: 0, by: -1) {
            guard let start = calendar.date(byAdding: .month, value: -offset, to: currentMonth.start),
                  let end = calendar.date(byAdding: .month, value: 1, to: start) else { continue }
            let monthIndex = calendar.component(.month, from: start) - 1
            buckets.append(PeriodBucket(label: calendar.shortMonthSymbols[monthIndex], interval: DateInterval(start: start, end: end)))
        }
        return buckets
    }

    /// Eight three-hour buckets across the day, labeled by start hour (12a, 3a, … 9p).
    private static func todayBuckets(now: Date, calendar: Calendar) -> [PeriodBucket] {
        guard let day = calendar.dateInterval(of: .day, for: now) else { return [] }
        var buckets: [PeriodBucket] = []
        for index in 0..<8 {
            let startHour = index * 3
            guard let start = calendar.date(byAdding: .hour, value: startHour, to: day.start),
                  let end = calendar.date(byAdding: .hour, value: startHour + 3, to: day.start) else { continue }
            buckets.append(PeriodBucket(label: hourLabel(startHour), interval: DateInterval(start: start, end: end)))
        }
        return buckets
    }

    /// Compact 12-hour clock label for an hour-of-day (0 → "12a", 13 → "1p").
    private static func hourLabel(_ hour: Int) -> String {
        let suffix = hour < 12 ? "a" : "p"
        let twelve = hour % 12 == 0 ? 12 : hour % 12
        return "\(twelve)\(suffix)"
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

    /// Fixed-step buckets ("MMM d"-labeled by start day) covering `interval`, e.g. daily for a
    /// month or weekly for a quarter. The final bucket is clipped to the interval's end.
    private static func steppedBuckets(in interval: DateInterval, stepDays: Int, calendar: Calendar) -> [PeriodBucket] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.timeZone = calendar.timeZone // label in the calendar's zone, not the device's
        formatter.dateFormat = "MMM d"
        var buckets: [PeriodBucket] = []
        var start = interval.start
        while start < interval.end {
            guard let next = calendar.date(byAdding: .day, value: stepDays, to: start) else { break }
            buckets.append(PeriodBucket(label: formatter.string(from: start),
                                        interval: DateInterval(start: start, end: min(next, interval.end))))
            start = next
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
