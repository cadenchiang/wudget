import XCTest
@testable import WalletBudget

/// Unit tests for `RecurrenceFrequency.nextOccurrence`. Uses a fixed UTC Gregorian calendar.
final class RecurrenceFrequencyTests: XCTestCase {
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func testNoneHasNoOccurrence() {
        XCTAssertNil(RecurrenceFrequency.none.nextOccurrence(from: date(2026, 1, 1), after: date(2026, 5, 1), calendar: utcCalendar))
    }

    func testMonthlyAdvancesPastNow() {
        let next = RecurrenceFrequency.monthly.nextOccurrence(
            from: date(2026, 1, 15),
            after: date(2026, 5, 1),
            calendar: utcCalendar
        )
        XCTAssertEqual(next, date(2026, 5, 15))
    }

    func testEveryTwoMonthsLandsOnCycle() {
        let next = RecurrenceFrequency.everyTwoMonths.nextOccurrence(
            from: date(2026, 1, 10),
            after: date(2026, 4, 1),
            calendar: utcCalendar
        )
        // Cycles: Jan 10, Mar 10, May 10 → first after Apr 1 is May 10.
        XCTAssertEqual(next, date(2026, 5, 10))
    }

    func testWeeklyAdvances() {
        let next = RecurrenceFrequency.weekly.nextOccurrence(
            from: date(2026, 5, 1),
            after: date(2026, 5, 10),
            calendar: utcCalendar
        )
        // May 1, 8, 15 → first after May 10 is May 15.
        XCTAssertEqual(next, date(2026, 5, 15))
    }

    func testFutureStartReturnsStart() {
        let start = date(2026, 6, 1)
        let next = RecurrenceFrequency.monthly.nextOccurrence(from: start, after: date(2026, 5, 1), calendar: utcCalendar)
        XCTAssertEqual(next, start)
    }
}
