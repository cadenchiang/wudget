import SwiftUI

/// Static catalog of category appearance options and the built-in default categories.
///
/// Colors are stored as palette names (not hex) so the picker is a simple fixed swatch grid and
/// the model stays human-readable.
enum CategoryCatalog {
    /// Named color palette. The stored `colorName` maps to one of these.
    static let palette: [String: Color] = [
        "red": .red, "orange": .orange, "yellow": .yellow, "green": .green,
        "mint": .mint, "teal": .teal, "blue": .blue, "indigo": .indigo,
        "purple": .purple, "pink": .pink, "brown": .brown, "gray": .gray,
    ]

    /// Color names offered in the color picker, in display order.
    static let colorChoices = [
        "red", "orange", "yellow", "green", "mint", "teal",
        "blue", "indigo", "purple", "pink", "brown", "gray",
    ]

    /// SF Symbols offered in the icon picker.
    static let iconChoices = [
        "cup.and.saucer.fill", "fork.knife", "cart.fill", "bag.fill", "car.fill", "fuelpump.fill",
        "house.fill", "bolt.fill", "drop.fill", "cross.case.fill", "pills.fill", "figure.run",
        "star.fill", "gamecontroller.fill", "music.note", "film.fill", "tv.fill", "airplane",
        "creditcard.fill", "dollarsign.circle.fill", "gift.fill", "pawprint.fill", "graduationcap.fill",
        "wrench.and.screwdriver.fill", "doc.text.fill", "phone.fill", "wifi", "tshirt", "square.grid.2x2.fill",
    ]

    /// Resolves a palette name to a `Color` (gray when unknown).
    static func color(named name: String) -> Color {
        palette[name] ?? .gray
    }

    /// A built-in category definition used for seeding and as a fallback.
    struct Default {
        let name: String
        let colorName: String
        let icon: String
        let keywords: [String]
    }

    /// The default categories the app seeds on first launch (also the fallback when no store).
    static let defaults: [Default] = [
        Default(name: "Coffee", colorName: "brown", icon: "cup.and.saucer.fill",
                keywords: ["coffee", "cafe", "café", "starbucks", "blue bottle", "peet", "dunkin"]),
        Default(name: "Groceries", colorName: "green", icon: "cart.fill",
                keywords: ["grocery", "market", "trader joe", "whole foods", "safeway", "costco", "aldi", "kroger"]),
        Default(name: "Dining", colorName: "orange", icon: "fork.knife",
                keywords: ["restaurant", "grill", "kitchen", "pizza", "sushi", "taco", "burger", "mcdonald", "chipotle", "panera"]),
        Default(name: "Transport", colorName: "blue", icon: "car.fill",
                keywords: ["uber", "lyft", "bart", "caltrain", "gas", "shell", "chevron", "exxon", "parking", "transit"]),
        Default(name: "Shopping", colorName: "yellow", icon: "bag.fill",
                keywords: ["amazon", "target", "walmart", "apple store", "best buy", "nike"]),
        Default(name: "Entertainment", colorName: "pink", icon: "star.fill",
                keywords: ["netflix", "spotify", "hulu", "disney", "cinema", "theater", "steam", "playstation", "xbox"]),
        Default(name: "Bills", colorName: "indigo", icon: "doc.text.fill",
                keywords: ["at&t", "verizon", "comcast", "pg&e", "electric", "water", "insurance", "rent", "mortgage"]),
        Default(name: "Health", colorName: "red", icon: "cross.case.fill",
                keywords: ["pharmacy", "cvs", "walgreens", "clinic", "hospital", "dental", "fitness", "gym"]),
        Default(name: "Other", colorName: "gray", icon: "square.grid.2x2.fill", keywords: []),
    ]
}
