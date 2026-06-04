import XCTest
@testable import WalletBudget

/// Unit tests for `LogoProvider`, which resolves Logo.dev image URLs for library items.
final class LogoProviderTests: XCTestCase {
    /// A known merchant name resolves to a Logo.dev URL for its mapped domain.
    func testKnownMerchantResolvesLogoDevURL() {
        let item = LibraryItem(name: "Starbucks", systemImage: "cup.and.saucer.fill", color: .green)
        let url = LogoProvider.logoURL(for: item)
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.host, "img.logo.dev")
        XCTAssertEqual(url?.path, "/starbucks.com")
        XCTAssertTrue(url?.query?.contains("token=pk_") == true)
    }

    /// An explicit `domain` on the item wins over the name-derived mapping.
    func testExplicitDomainOverridesNameLookup() {
        let item = LibraryItem(name: "Starbucks", systemImage: "cup.and.saucer.fill", color: .green, domain: "example.com")
        XCTAssertEqual(LogoProvider.logoURL(for: item)?.path, "/example.com")
    }

    /// An unknown merchant with no domain yields no URL, so callers fall back to the SF Symbol.
    func testUnknownMerchantReturnsNil() {
        let item = LibraryItem(name: "Joe's Diner", systemImage: "bag.fill", color: .gray)
        XCTAssertNil(LogoProvider.logoURL(for: item))
        XCTAssertNil(LogoProvider.fallbackURL(for: item))
    }

    /// The fallback tier still points at icon.horse for the same resolved domain.
    func testFallbackURLUsesIconHorse() {
        let item = LibraryItem(name: "Netflix", systemImage: "play.rectangle.fill", color: .red)
        let url = LogoProvider.fallbackURL(for: item)
        XCTAssertEqual(url?.host, "icon.horse")
        XCTAssertEqual(url?.path, "/icon/netflix.com")
    }

    /// Every branded card in the library resolves a logo URL; only the generic
    /// entries ("Debit Card", "Cash") intentionally have none.
    func testAllBrandedCardsResolveLogoURLs() {
        let genericNames: Set<String> = ["Debit Card", "Cash"]
        for item in CardLibrary.items {
            if genericNames.contains(item.name) {
                XCTAssertNil(LogoProvider.logoURL(for: item), "\(item.name) should stay an SF Symbol")
            } else {
                XCTAssertNotNil(LogoProvider.logoURL(for: item), "\(item.name) is missing a domain")
            }
        }
    }

    /// Every merchant in the library resolves a logo URL (all are in `knownDomains`).
    func testAllLibraryMerchantsResolveLogoURLs() {
        for item in MerchantLibrary.items {
            XCTAssertNotNil(LogoProvider.logoURL(for: item), "\(item.name) is missing a knownDomains entry")
        }
    }
}
