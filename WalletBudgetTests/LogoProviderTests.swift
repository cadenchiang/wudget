import UIKit
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

    /// The name → asset-name slug must collapse runs of non-alphanumerics to single underscores
    /// and trim edges, matching the rule used to generate the bundled logo imagesets.
    func testBundledLogoNameSlugs() {
        XCTAssertEqual(LibraryItem.bundledLogoName(for: "Starbucks"), "logo_starbucks")
        XCTAssertEqual(LibraryItem.bundledLogoName(for: "Peet's Coffee"), "logo_peet_s_coffee")
        XCTAssertEqual(LibraryItem.bundledLogoName(for: "Chick-fil-A"), "logo_chick_fil_a")
        XCTAssertEqual(LibraryItem.bundledLogoName(for: "H&M"), "logo_h_m")
        XCTAssertEqual(LibraryItem.bundledLogoName(for: "Disney+"), "logo_disney")
        XCTAssertEqual(LibraryItem.bundledLogoName(for: "AT&T"), "logo_at_t")
        XCTAssertEqual(LibraryItem.bundledLogoName(for: "In-N-Out"), "logo_in_n_out")
    }

    /// Every library item with a known domain must have its logo bundled in the asset catalog so
    /// tiles render instantly without a network fetch.
    func testEveryDomainBackedItemHasBundledLogo() {
        for item in MerchantLibrary.items + CardLibrary.items where LogoProvider.logoURL(for: item) != nil {
            let asset = item.assetName ?? ""
            XCTAssertNotNil(UIImage(named: asset),
                            "Missing bundled logo \"\(asset)\" for \(item.name)")
        }
    }
}
