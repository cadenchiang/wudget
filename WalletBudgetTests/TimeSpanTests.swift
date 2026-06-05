import XCTest
@testable import WalletBudget

/// Unit tests for `TimeSpan` (week/month/year intervals) and `SpendingSummary.filter`.
/// Uses a fixed UTC Gregorian calendar and explicit reference dates for determinism.
final class TimeSpanTests: XCTestCase {
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    /// Every span has a compact chip label, in the Robinhood "1D 1W 1M 3M YTD 1Y All" convention.
    func testShortLabels() {
        XCTAssertEqual(TimeSpan.today.shortLabel, "1D")
        XCTAssertEqual(TimeSpan.week.shortLabel, "1W")
        XCTAssertEqual(TimeSpan.month.shortLabel, "1M")
        XCTAssertEqual(TimeSpan.threeMonths.shortLabel, "3M")
        XCTAssertEqual(TimeSpan.yearToDate.shortLabel, "YTD")
        XCTAssertEqual(TimeSpan.year.shortLabel, "1Y")
        XCTAssertEqual(TimeSpan.all.shortLabel, "All")
    }

    /// 3M covers the current calendar month plus the two before it, and its previous interval
    /// is the three months immediately before that (the windows abut).
    func testThreeMonthsInterval() {
        let now = date(2026, 5, 15)
        let interval = TimeSpan.threeMonths.interval(now: now, calendar: utcCalendar)!
        XCTAssertTrue(interval.contains(date(2026, 3, 1)))
        XCTAssertTrue(interval.contains(date(2026, 5, 31)))
        XCTAssertFalse(interval.contains(date(2026, 2, 28)))
        let previous = TimeSpan.threeMonths.previousInterval(now: now, calendar: utcCalendar)!
        XCTAssertEqual(previous.end, interval.start)
        XCTAssertTrue(previous.contains(date(2025, 12, 1)))
    }

    /// YTD runs from January 1 to now; its previous interval is last year's start to the same
    /// date a year ago.
    func testYearToDateInterval() {
        let now = date(2026, 5, 15)
        let interval = TimeSpan.yearToDate.interval(now: now, calendar: utcCalendar)!
        XCTAssertTrue(interval.contains(date(2026, 1, 1)))
        XCTAssertEqual(interval.end, now)
        let previous = TimeSpan.yearToDate.previousInterval(now: now, calendar: utcCalendar)!
        XCTAssertTrue(previous.contains(date(2025, 1, 1)))
        XCTAssertEqual(previous.end, date(2025, 5, 15))
    }

    /// All time is unbounded: no interval, no previous interval, and a fixed subtitle.
    func testAllSpanIsUnbounded() {
        XCTAssertNil(TimeSpan.all.interval(now: date(2026, 5, 15), calendar: utcCalendar))
        XCTAssertNil(TimeSpan.all.previousInterval(now: date(2026, 5, 15), calendar: utcCalendar))
        XCTAssertEqual(TimeSpan.all.dateRange(now: date(2026, 5, 15), calendar: utcCalendar), "All time")
    }

    /// The new spans bucket fine-grained: weekly for 3M and YTD, trailing 12 months for All.
    func testNewSpanBuckets() {
        // English locale so labels are "Mar 1"-style, not the locale-less fallback.
        var calendar = utcCalendar
        calendar.locale = Locale(identifier: "en_US")
        let now = date(2026, 5, 15)
        let threeMonths = PeriodBucketizer.buckets(for: .threeMonths, now: now, calendar: calendar)
        XCTAssertEqual(threeMonths.first?.label, "Mar 1")
        XCTAssertEqual(threeMonths.count, 14) // 92 days in weekly steps
        let ytd = PeriodBucketizer.buckets(for: .yearToDate, now: now, calendar: calendar)
        XCTAssertEqual(ytd.first?.label, "Jan 1")
        XCTAssertEqual(ytd.count, 20) // Jan 1 through May 15 in weekly steps
        let all = PeriodBucketizer.buckets(for: .all, now: now, calendar: calendar)
        XCTAssertEqual(all.count, 12)
        XCTAssertEqual(all.last?.label, "May")
    }

    /// The cumulative chart line anchors at zero, steps at each transaction's exact timestamp,
    /// and runs flat to the line's end; entries beyond the end are ignored.
    func testCumulativeLine() {
        let start = date(2026, 5, 1)
        let end = date(2026, 5, 15)
        let entries = [
            SpendingChartEntry(date: date(2026, 5, 10), amount: 20, category: "Coffee"),
            SpendingChartEntry(date: date(2026, 5, 3), amount: 10, category: "Dining"),
            SpendingChartEntry(date: date(2026, 5, 20), amount: 99, category: "Ignored"), // after end
        ]
        let line = TotalSpendingCard.cumulativeLine(entries: entries, from: start, to: end)
        XCTAssertEqual(line.map(\.total), [0, 10, 30, 30])
        XCTAssertEqual(line.first?.date, start)
        XCTAssertEqual(line.last?.date, end)
    }

    /// Volume-bar totals group entries into their buckets by exact timestamp, largest category
    /// first, skipping empty buckets.
    func testBucketCategoryTotals() {
        let buckets = [
            PeriodBucket(label: "d1", interval: DateInterval(start: date(2026, 5, 1), end: date(2026, 5, 2))),
            PeriodBucket(label: "d2", interval: DateInterval(start: date(2026, 5, 2), end: date(2026, 5, 3))),
        ]
        let entries = [
            SpendingChartEntry(date: date(2026, 5, 1), amount: 5, category: "Coffee"),
            SpendingChartEntry(date: date(2026, 5, 1), amount: 30, category: "Dining"),
        ]
        let totals = TotalSpendingCard.bucketCategoryTotals(entries: entries, buckets: buckets)
        XCTAssertEqual(totals.count, 1) // empty second bucket skipped
        XCTAssertEqual(totals.first?.bucket.label, "d1")
        XCTAssertEqual(totals.first?.totals.first?.category, "Dining") // largest first
        XCTAssertEqual(totals.first?.totals.last?.amount, 5)
    }

    func testMonthBoundsToCalendarMonth() {
        let interval = TimeSpan.month.interval(now: date(2026, 5, 15), calendar: utcCalendar)
        XCTAssertNotNil(interval)
        XCTAssertTrue(interval!.contains(date(2026, 5, 1)))
        XCTAssertFalse(interval!.contains(date(2026, 4, 30)))
        XCTAssertFalse(interval!.contains(date(2026, 6, 1)))
    }

    func testYearBoundsToCalendarYear() {
        let interval = TimeSpan.year.interval(now: date(2026, 5, 15), calendar: utcCalendar)
        XCTAssertNotNil(interval)
        XCTAssertTrue(interval!.contains(date(2026, 1, 1)))
        XCTAssertFalse(interval!.contains(date(2025, 12, 31)))
    }

    func testPreviousMonthInterval() {
        let interval = TimeSpan.month.previousInterval(now: date(2026, 5, 15), calendar: utcCalendar)
        XCTAssertNotNil(interval)
        XCTAssertTrue(interval!.contains(date(2026, 4, 10)))
        XCTAssertFalse(interval!.contains(date(2026, 5, 10)))
    }

    func testFilterWithNilIntervalReturnsAll() {
        let expenses = [
            Expense(amount: 5, merchant: "A", date: date(2020, 1, 1)),
            Expense(amount: 5, merchant: "B", date: date(2026, 5, 1)),
        ]
        XCTAssertEqual(SpendingSummary.filter(expenses, in: nil).count, 2)
    }

    func testFilterAppliesMonthInterval() {
        let inside = Expense(amount: 5, merchant: "A", date: date(2026, 5, 10))
        let outside = Expense(amount: 5, merchant: "B", date: date(2026, 4, 10))
        let interval = TimeSpan.month.interval(now: date(2026, 5, 15), calendar: utcCalendar)
        let result = SpendingSummary.filter([inside, outside], in: interval)
        XCTAssertEqual(result.map(\.merchant), ["A"])
    }
}
