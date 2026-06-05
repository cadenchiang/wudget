import XCTest
@testable import WalletBudget

/// Unit tests for grouping and bucket aggregation in `SpendingSummary`, plus
/// `PeriodBucketizer`. Uses a fixed UTC Gregorian calendar for determinism.
final class SpendingGroupingTests: XCTestCase {
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func testGroupsByCategoryWithCountAndDelta() {
        let current = [
            Expense(amount: 4, merchant: "Blue Bottle Coffee"), // Coffee
            Expense(amount: 6, merchant: "Starbucks"),          // Coffee
            Expense(amount: 20, merchant: "Whole Foods Market"), // Groceries
        ]
        let previous = [
            Expense(amount: 10, merchant: "Peet's Coffee"),     // Coffee
        ]
        let groups = SpendingSummary.groups(current: current, previous: previous, by: .category)

        XCTAssertEqual(groups.map(\.key), ["Groceries", "Coffee"])
        let coffee = groups.first { $0.key == "Coffee" }!
        XCTAssertEqual(coffee.total, 10)
        XCTAssertEqual(coffee.count, 2)
        XCTAssertEqual(coffee.previousTotal, 10)
        XCTAssertEqual(coffee.delta, 0)
        XCTAssertTrue(coffee.hasComparison)

        let groceries = groups.first { $0.key == "Groceries" }!
        XCTAssertEqual(groceries.previousTotal, 0)
        XCTAssertFalse(groceries.hasComparison)
    }

    func testGroupsByMerchant() {
        let current = [
            Expense(amount: 4, merchant: "Cafe X"),
            Expense(amount: 6, merchant: "Cafe X"),
            Expense(amount: 20, merchant: "Store Y"),
        ]
        let groups = SpendingSummary.groups(current: current, previous: [], by: .merchant)
        XCTAssertEqual(groups.map(\.key), ["Store Y", "Cafe X"])
        XCTAssertEqual(groups.first { $0.key == "Cafe X" }!.count, 2)
    }

    func testEmptyMerchantBecomesUnknown() {
        let groups = SpendingSummary.groups(current: [Expense(amount: 5, merchant: "")], previous: [], by: .merchant)
        XCTAssertEqual(groups.first?.key, "Unknown")
    }

    func testMonthBucketsCoverEveryDay() {
        var calendar = utcCalendar
        calendar.locale = Locale(identifier: "en_US")
        let buckets = PeriodBucketizer.buckets(for: .month, now: date(2026, 5, 15), calendar: calendar)
        XCTAssertEqual(buckets.count, 31) // daily buckets
        XCTAssertEqual(buckets.first?.label, "May 1")
        XCTAssertEqual(buckets.last?.label, "May 31")
        XCTAssertTrue(buckets.first!.interval.contains(date(2026, 5, 1)))
        XCTAssertTrue(buckets.last!.interval.contains(date(2026, 5, 31)))
    }

    func testBucketTotalsSumIntoBuckets() {
        var calendar = utcCalendar
        calendar.locale = Locale(identifier: "en_US")
        let buckets = PeriodBucketizer.buckets(for: .month, now: date(2026, 5, 15), calendar: calendar)
        let expenses = [
            Expense(amount: 10, merchant: "A", date: date(2026, 5, 2)),  // May 2
            Expense(amount: 5, merchant: "B", date: date(2026, 5, 3)),   // May 3
            Expense(amount: 7, merchant: "C", date: date(2026, 5, 30)),  // 29-31
        ]
        let totals = SpendingSummary.bucketTotals(expenses, buckets: buckets)
        XCTAssertEqual(totals.first { $0.label == "May 2" }?.total, 10)
        XCTAssertEqual(totals.first { $0.label == "May 3" }?.total, 5)
        XCTAssertEqual(totals.first { $0.label == "May 8" }?.total, 0)
    }

    func testYearBucketsAreTwelveMonths() {
        let buckets = PeriodBucketizer.buckets(for: .year, now: date(2026, 5, 15), calendar: utcCalendar)
        XCTAssertEqual(buckets.count, 12)
    }

    func testCategorySegmentsSplitBucketsByCategory() {
        var calendar = utcCalendar
        calendar.locale = Locale(identifier: "en_US")
        let buckets = PeriodBucketizer.buckets(for: .month, now: date(2026, 5, 15), calendar: calendar)
        let expenses = [
            Expense(amount: 10, merchant: "Starbucks", date: date(2026, 5, 2)),          // Coffee, May 2
            Expense(amount: 30, merchant: "Whole Foods Market", date: date(2026, 5, 2)), // Groceries, May 2
            Expense(amount: 7, merchant: "Peet's Coffee", date: date(2026, 5, 30)),      // Coffee, May 30
        ]
        let segments = SpendingSummary.categorySegments(expenses, buckets: buckets)

        let firstBucket = segments.filter { $0.bucketLabel == "May 2" }
        XCTAssertEqual(firstBucket.count, 2)
        // Sorted by total descending → Groceries (30) before Coffee (10).
        XCTAssertEqual(firstBucket.first?.category, "Groceries")
        XCTAssertEqual(firstBucket.first?.total, 30)

        XCTAssertEqual(segments.first { $0.bucketLabel == "May 30" }?.total, 7)
        XCTAssertTrue(segments.allSatisfy { $0.total > 0 })
    }
}
