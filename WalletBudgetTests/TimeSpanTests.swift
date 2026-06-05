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

    /// The new spans bucket into trailing months: 3 for 3M, months-elapsed for YTD, 12 for All.
    func testNewSpanBuckets() {
        // English locale so month symbols are "Mar"-style, not the locale-less "M03" fallback.
        var calendar = utcCalendar
        calendar.locale = Locale(identifier: "en_US")
        let now = date(2026, 5, 15)
        XCTAssertEqual(PeriodBucketizer.buckets(for: .threeMonths, now: now, calendar: calendar).map(\.label), ["Mar", "Apr", "May"])
        XCTAssertEqual(PeriodBucketizer.buckets(for: .yearToDate, now: now, calendar: calendar).count, 5)
        let all = PeriodBucketizer.buckets(for: .all, now: now, calendar: calendar)
        XCTAssertEqual(all.count, 12)
        XCTAssertEqual(all.last?.label, "May")
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
