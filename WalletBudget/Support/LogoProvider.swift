import Foundation

/// Resolves logo image URLs for merchants/cards.
///
/// Remote logo fetching is intentionally disabled: the previous logo service (Clearbit) was
/// discontinued, so every lookup failed with a DNS error and logged noise. Just as importantly,
/// sending merchant names to a third-party service conflicts with the app's on-device,
/// no-data-leaves-your-phone model. Merchant/card tiles therefore use bundled asset images when
/// present, otherwise the colored SF Symbol fallback. This returns `nil` so callers use those.
enum LogoProvider {
    /// Always `nil` (remote logo fetching is disabled — see the type's note).
    /// - Parameter item: The library item (unused).
    /// - Returns: `nil`.
    static func url(for item: LibraryItem) -> URL? { nil }
}
