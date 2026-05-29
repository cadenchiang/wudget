import Foundation

/// Derives a spending category from a merchant name, and exposes the current category list.
///
/// Backed by `CategoryRegistry` (the user's categories), so renamed/custom categories are
/// reflected. Falls back to the built-in defaults when no categories are loaded.
enum ExpenseCategorizer {
    /// Category used when nothing matches or input is empty.
    static let uncategorized = "Other"

    /// All categories the app currently knows about, in display order.
    static var allCategories: [String] {
        CategoryRegistry.active.map(\.name)
    }

    /// Best-guess category for a merchant name (case-insensitive keyword match).
    /// - Parameter merchant: The raw merchant name.
    /// - Returns: A category name, or `uncategorized` ("Other") when nothing matches.
    static func category(for merchant: String) -> String {
        CategoryRegistry.categorize(merchant)
    }
}
