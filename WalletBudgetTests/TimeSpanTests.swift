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

    /// Every span has a compact chip label, in the Robinhood "1D 1W 1M 1Y" convention.
    func testShortLabels() {
        XCTAssertEqual(TimeSpan.today.shortLabel, "1D")
        XCTAssertEqual(TimeSpan.week.shortLabel, "1W")
        XCTAssertEqual(TimeSpan.month.shortLabel, "1M")
        XCTAssertEqual(TimeSpan.year.shortLabel, "1Y")
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
