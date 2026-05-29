import XCTest
@testable import WalletBudget

/// Unit tests for `ExpenseCategorizer`. Pure logic; no Simulator required.
final class ExpenseCategorizerTests: XCTestCase {
    func testCoffeeMerchant() {
        XCTAssertEqual(ExpenseCategorizer.category(for: "Blue Bottle Coffee"), "Coffee")
    }

    func testGroceriesMerchant() {
        XCTAssertEqual(ExpenseCategorizer.category(for: "Whole Foods Market"), "Groceries")
    }

    func testTransportMerchant() {
        XCTAssertEqual(ExpenseCategorizer.category(for: "Uber Trip Help.uber.com"), "Transport")
    }

    func testCaseInsensitive() {
        XCTAssertEqual(ExpenseCategorizer.category(for: "STARBUCKS #1234"), "Coffee")
    }

    func testUnknownMerchantIsOther() {
        XCTAssertEqual(ExpenseCategorizer.category(for: "Some Random LLC"), "Other")
    }

    func testEmptyMerchantIsOther() {
        XCTAssertEqual(ExpenseCategorizer.category(for: ""), "Other")
    }
}
