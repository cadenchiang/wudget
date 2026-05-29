import Foundation

/// Builds runtime logo image URLs for merchants/cards from a domain.
///
/// This is how finance apps surface real logos: fetch them on demand from a logo service rather
/// than bundling copyrighted files. The service is configurable via `baseURLFormat`; the domain
/// comes from the item's explicit `domain` or is derived from its name. Views load the URL with
/// `AsyncImage` and fall back to the SF Symbol while loading or on failure.
enum LogoProvider {
    /// Logo service URL format. `%@` is replaced by the domain (e.g. "amazon.com").
    static let baseURLFormat = "https://logo.clearbit.com/%@"

    /// The logo URL for a library item, or `nil` when no domain can be determined.
    static func url(for item: LibraryItem) -> URL? {
        guard let domain = item.domain ?? derivedDomain(from: item.name) else { return nil }
        return URL(string: String(format: baseURLFormat, domain))
    }

    /// Derives a best-guess domain from a display name (e.g. "Best Buy" → "bestbuy.com").
    ///
    /// Imperfect by design: when the guess is wrong the logo simply fails to load and the SF
    /// Symbol fallback shows, so a bad guess never breaks the UI.
    static func derivedDomain(from name: String) -> String? {
        let cleaned = name.lowercased().unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
        guard !cleaned.isEmpty else { return nil }
        return cleaned + ".com"
    }
}
