import Foundation

/// Cleans a raw merchant string (as delivered by the Apple Wallet automation, e.g.
/// "Goodwill #110419" or "COSTCO WHSE #0123") into a display-friendly merchant name by
/// stripping the trailing store-number suffix.
///
/// Many merchants append a per-location store number to the payee name on the card statement
/// that Wallet hands to the automation. That number is noise for the user, so we remove a single
/// trailing `#…` token (and the whitespace before it). Everything else about the name is left
/// untouched, so casing and spacing are preserved exactly as received.
enum MerchantCleaner {
    /// Trailing store-number suffix: optional whitespace, a `#`, then one or more
    /// number/letter/`-`/`.`/`_` characters, anchored to the end of the string.
    /// Example matches: " #110419", " #0123", "#A12-3".
    private static let storeNumberSuffix = "\\s*#[A-Za-z0-9._-]+\\s*$"

    /// Removes a trailing store-number suffix from a merchant name.
    ///
    /// - Parameter raw: The merchant string from the import (may include a trailing `#store`).
    /// - Returns: The trimmed merchant name with any single trailing `#…` token removed. If the
    ///   input is empty, or the suffix is the *entire* string (so stripping would leave nothing),
    ///   the trimmed original is returned unchanged so a faithful name is always preserved.
    static func clean(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        guard let range = trimmed.range(of: storeNumberSuffix, options: .regularExpression) else {
            return trimmed
        }

        let stripped = trimmed.replacingCharacters(in: range, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Never let the suffix swallow the whole name (e.g. a bare "#110419").
        return stripped.isEmpty ? trimmed : stripped
    }
}
