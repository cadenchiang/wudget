import XCTest
@testable import WalletBudget

/// Unit tests for `WidgetSnapshot`'s scope-aware math: total vs everyday (variable) spending,
/// budget remaining/percent/over-budget, and backward-compatible decoding of old snapshots.
final class WidgetSnapshotTests: XCTestCase {
    private func makeSnapshot(spent: Double = 500, variable: Double? = 300, budget: Double = 1000) -> WidgetSnapshot {
        WidgetSnapshot(monthSpent: spent, monthVariableSpent: variable, monthBudget: budget,
                       periodLabel: "Jun", currencyCode: "USD", recent: [])
    }

    func testSpentHonorsScope() {
        let snapshot = makeSnapshot()
        XCTAssertEqual(snapshot.spent(variableOnly: false), 500)
        XCTAssertEqual(snapshot.spent(variableOnly: true), 300)
    }

    func testVariableSpentFallsBackToTotalWhenMissing() {
        let snapshot = makeSnapshot(variable: nil)
        XCTAssertEqual(snapshot.spent(variableOnly: true), 500)
    }

    func testRemainingPercentAndOverBudgetPerScope() {
        let snapshot = makeSnapshot()
        XCTAssertEqual(snapshot.remaining(spent: 500), 500)
        XCTAssertEqual(snapshot.remaining(spent: 300), 700)
        XCTAssertEqual(snapshot.percentUsed(spent: 500), 50)
        XCTAssertEqual(snapshot.percentUsed(spent: 300), 30)
        XCTAssertFalse(snapshot.isOverBudget(spent: 500))
        XCTAssertTrue(snapshot.isOverBudget(spent: 1200))
    }

    func testNoBudgetEdgeCases() {
        let snapshot = makeSnapshot(budget: 0)
        XCTAssertFalse(snapshot.hasBudget)
        XCTAssertEqual(snapshot.percentUsed(spent: 500), 0)
        XCTAssertFalse(snapshot.isOverBudget(spent: 500))
    }

    func testDecodesLegacySnapshotWithoutVariableField() throws {
        // Snapshot JSON written by an app version that predates monthVariableSpent.
        let legacy = """
        {"monthSpent": 250, "monthBudget": 800, "periodLabel": "Jun", "currencyCode": "USD", "recent": []}
        """.data(using: .utf8)!
        let snapshot = try JSONDecoder().decode(WidgetSnapshot.self, from: legacy)
        XCTAssertNil(snapshot.monthVariableSpent)
        XCTAssertEqual(snapshot.spent(variableOnly: true), 250)
        XCTAssertEqual(snapshot.spent(variableOnly: false), 250)
    }
}
