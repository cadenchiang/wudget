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
        let buckets = PeriodBucketizer.buckets(for: .month, now: date(2026, 5, 15), calendar: utcCalendar)
        XCTAssertEqual(buckets.first?.label, "1-7")
        XCTAssertEqual(buckets.last?.label, "29-31")
        XCTAssertTrue(buckets.first!.interval.contains(date(2026, 5, 3)))
        XCTAssertTrue(buckets.last!.interval.contains(date(2026, 5, 31)))
    }

    func testBucketTotalsSumIntoBuckets() {
        let buckets = PeriodBucketizer.buckets(for: .month, now: date(2026, 5, 15), calendar: utcCalendar)
        let expenses = [
            Expense(amount: 10, merchant: "A", date: date(2026, 5, 2)),  // 1-7
            Expense(amount: 5, merchant: "B", date: date(2026, 5, 3)),   // 1-7
            Expense(amount: 7, merchant: "C", date: date(2026, 5, 30)),  // 29-31
        ]
        let totals = SpendingSummary.bucketTotals(expenses, buckets: buckets)
        XCTAssertEqual(totals.first { $0.label == "1-7" }?.total, 15)
        XCTAssertEqual(totals.first { $0.label == "29-31" }?.total, 7)
        XCTAssertEqual(totals.first { $0.label == "8-14" }?.total, 0)
    }

    func testYearBucketsAreTwelveMonths() {
        let buckets = PeriodBucketizer.buckets(for: .year, now: date(2026, 5, 15), calendar: utcCalendar)
        XCTAssertEqual(buckets.count, 12)
    }

    func testCategorySegmentsSplitBucketsByCategory() {
        let buckets = PeriodBucketizer.buckets(for: .month, now: date(2026, 5, 15), calendar: utcCalendar)
        let expenses = [
            Expense(amount: 10, merchant: "Starbucks", date: date(2026, 5, 2)),       // Coffee, 1-7
            Expense(amount: 30, merchant: "Whole Foods Market", date: date(2026, 5, 3)), // Groceries, 1-7
            Expense(amount: 7, merchant: "Peet's Coffee", date: date(2026, 5, 30)),    // Coffee, 29-31
        ]
        let segments = SpendingSummary.categorySegments(expenses, buckets: buckets)

        let firstBucket = segments.filter { $0.bucketLabel == "1-7" }
        XCTAssertEqual(firstBucket.count, 2)
        // Sorted by total descending → Groceries (30) before Coffee (10).
        XCTAssertEqual(firstBucket.first?.category, "Groceries")
        XCTAssertEqual(firstBucket.first?.total, 30)

        XCTAssertEqual(segments.first { $0.bucketLabel == "29-31" }?.total, 7)
        XCTAssertTrue(segments.allSatisfy { $0.total > 0 })
    }
}
