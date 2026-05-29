import SwiftUI
import UIKit

/// Resolves a color and SF Symbol for category or merchant keys, reading the user's categories
/// from `CategoryRegistry` (falling back to a deterministic palette for unknown keys).
enum CategoryStyle {
    /// The color for a key: the category's chosen color, or a deterministic palette color for
    /// arbitrary keys (e.g. merchant names).
    static func color(for key: String) -> Color {
        if let info = CategoryRegistry.info(named: key) {
            return CategoryCatalog.color(named: info.colorName)
        }
        let choices = CategoryCatalog.colorChoices
        let index = key.unicodeScalars.reduce(0) { $0 + Int($1.value) } % choices.count
        return CategoryCatalog.color(named: choices[index])
    }

    /// The SF Symbol for a key: the category's chosen icon, or a generic tag for unknown keys.
    static func icon(for key: String) -> String {
        CategoryRegistry.info(named: key)?.icon ?? "tag.fill"
    }

    /// Renders a colored rounded-square tile (white symbol on the category color) as a `UIImage`,
    /// for use inside SwiftUI menus/pickers that otherwise template SF Symbols to one tint.
    static func tileImage(for key: String, size: CGFloat = 28) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { _ in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            let tile = UIBezierPath(roundedRect: rect, cornerRadius: size * 0.28)
            UIColor(color(for: key)).setFill()
            tile.fill()

            let config = UIImage.SymbolConfiguration(pointSize: size * 0.52, weight: .semibold)
            if let symbol = UIImage(systemName: icon(for: key), withConfiguration: config)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                let origin = CGPoint(x: (size - symbol.size.width) / 2, y: (size - symbol.size.height) / 2)
                symbol.draw(at: origin)
            }
        }
    }
}
