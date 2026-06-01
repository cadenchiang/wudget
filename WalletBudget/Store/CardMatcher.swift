import Foundation

/// Maps a raw card string (as delivered by the Apple Wallet automation, e.g. "Visa •••• 1234" or
/// "CHASE SAPPHIRE RESERVE") to a known `CardLibrary` entry so the transaction links to a card in
/// our database (and picks up its icon/color). Falls back to the cleaned raw string when nothing
/// matches, so an unknown card is still recorded faithfully.
enum CardMatcher {
    /// Best-effort canonical card name for a raw card string.
    ///
    /// Resolution order:
    /// 1. Exact, case-insensitive match to a library entry.
    /// 2. A library name contained in the raw string; the longest match wins so "Chase Sapphire"
    ///    beats "Chase" for "CHASE SAPPHIRE RESERVE".
    /// 3. The raw string contained in a library name (e.g. "sapphire" → "Chase Sapphire"), guarded
    ///    to reasonably specific input to avoid spurious matches.
    ///
    /// - Parameter raw: The card string from the import (may include masking digits, casing, etc.).
    /// - Returns: A canonical `CardLibrary` name, or the trimmed raw string when no match is found
    ///   (empty in, empty out).
    static func match(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        // 1. Exact match.
        if let exact = CardLibrary.item(named: trimmed) { return exact.name }

        let lower = trimmed.lowercased()

        // 2. Longest library name contained in the raw string.
        if let contained = CardLibrary.items
            .filter({ lower.contains($0.name.lowercased()) })
            .max(by: { $0.name.count < $1.name.count }) {
            return contained.name
        }

        // 3. Raw contained in a library name (only for reasonably specific input).
        if lower.count >= 5,
           let reverse = CardLibrary.items.first(where: { $0.name.lowercased().contains(lower) }) {
            return reverse.name
        }

        return trimmed
    }
}
