import Foundation
import SwiftData

/// A user-manageable spending category: its name, appearance, ordering, and (seeded, non-edited)
/// keywords used for auto-categorization of merchants.
@Model
final class SpendingCategory {
    /// Unique, user-facing name. Also the value stored on `Expense.category`.
    @Attribute(.unique) var name: String
    /// Palette color name (see `CategoryCatalog.palette`).
    var colorName: String
    /// SF Symbol name.
    var iconName: String
    /// Display/order position.
    var sortOrder: Int
    /// Comma-joined auto-categorization keywords (empty for custom categories).
    var keywordsRaw: String

    /// Parsed keywords.
    var keywords: [String] {
        keywordsRaw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Creates a category.
    /// - Parameters:
    ///   - name: Unique name.
    ///   - colorName: Palette color name.
    ///   - iconName: SF Symbol name.
    ///   - sortOrder: Display position.
    ///   - keywords: Auto-categorization keywords (joined and stored).
    init(name: String, colorName: String, iconName: String, sortOrder: Int, keywords: [String] = []) {
        self.name = name
        self.colorName = colorName
        self.iconName = iconName
        self.sortOrder = sortOrder
        self.keywordsRaw = keywords.joined(separator: ",")
    }
}
