import XCTest
@testable import WalletBudget

/// Unit tests for `CurrencyParser`. Pure Foundation logic; no Simulator required.
final class CurrencyParserTests: XCTestCase {
    func testParsesPlainDecimal() {
        XCTAssertEqual(CurrencyParser.parse("6.22"), 6.22)
    }

    func testStripsLeadingCurrencySymbol() {
        XCTAssertEqual(CurrencyParser.parse("$6.22"), 6.22)
    }

    func testStripsThousandsSeparator() {
        XCTAssertEqual(CurrencyParser.parse("1,234.50"), 1234.50)
    }

    func testStripsCurrencyCodeAndWhitespace() {
        XCTAssertEqual(CurrencyParser.parse("  USD 12  "), 12)
    }

    func testParenthesesMeanNegative() {
        XCTAssertEqual(CurrencyParser.parse("(3.00)"), -3.00)
    }

    func testExplicitNegative() {
        XCTAssertEqual(CurrencyParser.parse("-5.00"), -5.00)
    }

    func testIntegerWithoutDecimal() {
        XCTAssertEqual(CurrencyParser.parse("$1,000"), 1000)
    }

    func testEmptyStringReturnsNil() {
        XCTAssertNil(CurrencyParser.parse(""))
        XCTAssertNil(CurrencyParser.parse("   "))
    }

    func testNonNumericReturnsNil() {
        XCTAssertNil(CurrencyParser.parse("abc"))
    }
}
