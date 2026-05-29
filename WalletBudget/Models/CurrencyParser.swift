import Foundation

/// Parses free-form amount strings (as delivered by the Wallet Shortcut) into a `Double`.
///
/// The Wallet/Transaction automation may hand the amount over as a currency-formatted
/// string such as "$6.22", "1,234.50", or "(3.00)" for a refund/negative. This parser
/// normalizes those forms. It is intentionally Foundation-only so it can be unit tested
/// without the iOS Simulator.
enum CurrencyParser {
    /// Attempts to parse a currency/amount string into a numeric value.
    ///
    /// Handles: leading/trailing currency symbols and letters, thousands separators,
    /// surrounding whitespace, and parentheses-as-negative accounting notation.
    ///
    /// - Parameter raw: The amount string to parse.
    /// - Returns: The parsed `Double`, or `nil` when no numeric value can be extracted.
    ///            Negative results are returned as-is (callers store the absolute value).
    static func parse(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            Log.parsing.error("Amount parse failed: empty input")
            return nil
        }

        // Accounting-style negatives: "(3.00)" means -3.00.
        let isParenNegative = trimmed.hasPrefix("(") && trimmed.hasSuffix(")")

        // Keep only digits, decimal point, and minus sign; drop currency symbols,
        // letters, commas, and parentheses.
        var allowed = CharacterSet(charactersIn: "0123456789.-")
        allowed.formUnion(.whitespaces)
        let filtered = trimmed.unicodeScalars
            .filter { allowed.contains($0) }
            .map(String.init)
            .joined()
            .replacingOccurrences(of: " ", with: "")

        guard let value = Double(filtered) else {
            Log.parsing.error("Amount parse failed for input: \(raw, privacy: .public)")
            return nil
        }

        let signed = isParenNegative ? -abs(value) : value
        return signed
    }
}
