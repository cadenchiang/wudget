import XCTest
@testable import WalletBudget

/// Unit tests for `SpendingSummary`. Builds in-memory `Expense` instances (no container
/// needed) and uses a fixed UTC Gregorian calendar so month bucketing is deterministic.
final class SpendingSummaryTests: XCTestCase {
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func testTotalSumsAmounts() {
        let expenses = [
            Expense(amount: 10, merchant: "A"),
            Expense(amount: 20.50, merchant: "B"),
        ]
        XCTAssertEqual(SpendingSummary.total(expenses), 30.50, accuracy: 0.0001)
    }

    func testTotalOfEmptyIsZero() {
        XCTAssertEqual(SpendingSummary.total([]), 0)
    }

    func testInMonthFiltersByCalendarMonth() {
        let inside1 = Expense(amount: 5, merchant: "A", date: date(2026, 5, 1))
        let inside2 = Expense(amount: 7, merchant: "B", date: date(2026, 5, 31))
        let beforeMonth = Expense(amount: 9, merchant: "C", date: date(2026, 4, 30))
        let afterMonth = Expense(amount: 3, merchant: "D", date: date(2026, 6, 1))

        let result = SpendingSummary.inMonth(
            of: date(2026, 5, 15),
            expenses: [inside1, inside2, beforeMonth, afterMonth],
            calendar: utcCalendar
        )

        XCTAssertEqual(Set(result.map(\.merchant)), ["A", "B"])
    }

    func testByCategoryGroupsAndSortsDescending() {
        let expenses = [
            Expense(amount: 4, merchant: "Blue Bottle Coffee"), // Coffee
            Expense(amount: 6, merchant: "Starbucks"),          // Coffee
            Expense(amount: 20, merchant: "Whole Foods Market"), // Groceries
        ]
        let totals = SpendingSummary.byCategory(expenses)
        XCTAssertEqual(totals.map(\.category), ["Groceries", "Coffee"])
        XCTAssertEqual(totals.first?.total, 20)
        XCTAssertEqual(totals.last?.total, 10)
    }

    // MARK: - Budget allowance math

    /// Daily/weekly allowances divide the monthly budget by the month's days.
    func testBudgetAllowances() {
        XCTAssertEqual(BudgetEditorView.perDay(monthly: 3000, daysInMonth: 30), 100)
        XCTAssertEqual(BudgetEditorView.perWeek(monthly: 3000, daysInMonth: 30), 700)
        XCTAssertEqual(BudgetEditorView.perDay(monthly: 3100, daysInMonth: 31), 100)
        // Degenerate inputs are 0, never NaN/inf.
        XCTAssertEqual(BudgetEditorView.perDay(monthly: 0, daysInMonth: 30), 0)
        XCTAssertEqual(BudgetEditorView.perDay(monthly: -5, daysInMonth: 30), 0)
        XCTAssertEqual(BudgetEditorView.perDay(monthly: 100, daysInMonth: 0), 0)
        XCTAssertEqual(BudgetEditorView.perWeek(monthly: 0, daysInMonth: 30), 0)
    }
}
