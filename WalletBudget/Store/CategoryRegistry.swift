import Foundation

/// A lightweight snapshot of a category's display + matching data.
struct CategoryInfo: Equatable {
    let name: String
    let colorName: String
    let icon: String
    let keywords: [String]
}

/// In-memory cache of the user's categories, refreshed from SwiftData.
///
/// `ExpenseCategorizer` and `CategoryStyle` read from here so they can resolve names/colors/icons
/// synchronously (no model context needed). When the cache is empty (e.g. unit tests, or before
/// the first refresh) it falls back to `CategoryCatalog.defaults`, so behavior is always defined.
enum CategoryRegistry {
    private static var cache: [CategoryInfo] = []

    /// Replaces the cache from the current categories (ordered by `sortOrder`).
    static func refresh(_ categories: [SpendingCategory]) {
        cache = categories
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { CategoryInfo(name: $0.name, colorName: $0.colorName, icon: $0.iconName, keywords: $0.keywords) }
    }

    /// The active categories: the cache, or the built-in defaults when the cache is empty.
    static var active: [CategoryInfo] {
        cache.isEmpty
            ? CategoryCatalog.defaults.map { CategoryInfo(name: $0.name, colorName: $0.colorName, icon: $0.icon, keywords: $0.keywords) }
            : cache
    }

    /// Looks up a category by (case-insensitive) name.
    static func info(named name: String) -> CategoryInfo? {
        active.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Best-guess category name for a merchant via keyword match (falls back to "Other").
    static func categorize(_ merchant: String) -> String {
        let needle = merchant.lowercased()
        guard !needle.isEmpty else { return "Other" }
        for info in active where info.keywords.contains(where: { needle.contains($0) }) {
            return info.name
        }
        return "Other"
    }
}
