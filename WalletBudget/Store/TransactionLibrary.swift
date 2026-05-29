import SwiftUI

/// A pickable library entry (merchant or card) shown as a colored icon tile with a name.
///
/// Icons are SF Symbols, not brand logos (real logos are trademarked and can't be bundled),
/// chosen to evoke each brand. The library is an input aid only; the picked `name` is what
/// gets stored on the `Expense`.
struct LibraryItem: Identifiable {
    var id: String { name }
    let name: String
    let systemImage: String
    let color: Color
}

/// Common merchants offered in the merchant picker.
enum MerchantLibrary {
    static let items: [LibraryItem] = [
        LibraryItem(name: "Apple", systemImage: "applelogo", color: .black),
        LibraryItem(name: "Amazon", systemImage: "shippingbox.fill", color: .orange),
        LibraryItem(name: "Starbucks", systemImage: "cup.and.saucer.fill", color: .green),
        LibraryItem(name: "Dunkin'", systemImage: "cup.and.saucer.fill", color: .orange),
        LibraryItem(name: "Peet's Coffee", systemImage: "cup.and.saucer.fill", color: .brown),
        LibraryItem(name: "Whole Foods", systemImage: "leaf.fill", color: .green),
        LibraryItem(name: "Trader Joe's", systemImage: "cart.fill", color: .red),
        LibraryItem(name: "Safeway", systemImage: "cart.fill", color: .red),
        LibraryItem(name: "Costco", systemImage: "cart.fill", color: .blue),
        LibraryItem(name: "Target", systemImage: "target", color: .red),
        LibraryItem(name: "Walmart", systemImage: "cart.fill", color: .blue),
        LibraryItem(name: "Best Buy", systemImage: "desktopcomputer", color: .blue),
        LibraryItem(name: "Nike", systemImage: "figure.run", color: .black),
        LibraryItem(name: "Uber", systemImage: "car.fill", color: .black),
        LibraryItem(name: "Lyft", systemImage: "car.fill", color: .pink),
        LibraryItem(name: "Shell", systemImage: "fuelpump.fill", color: .yellow),
        LibraryItem(name: "Chevron", systemImage: "fuelpump.fill", color: .blue),
        LibraryItem(name: "Chipotle", systemImage: "fork.knife", color: .red),
        LibraryItem(name: "McDonald's", systemImage: "fork.knife", color: .yellow),
        LibraryItem(name: "DoorDash", systemImage: "bag.fill", color: .red),
        LibraryItem(name: "Netflix", systemImage: "play.rectangle.fill", color: .red),
        LibraryItem(name: "Spotify", systemImage: "music.note", color: .green),
        LibraryItem(name: "CVS", systemImage: "cross.case.fill", color: .red),
        LibraryItem(name: "Walgreens", systemImage: "cross.case.fill", color: .red),
    ]

    /// Looks up a library item by exact (case-insensitive) name.
    static func item(named name: String) -> LibraryItem? {
        items.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }
}

/// Common cards/payment methods offered in the card picker.
enum CardLibrary {
    static let items: [LibraryItem] = [
        LibraryItem(name: "Apple Card", systemImage: "creditcard.fill", color: .black),
        LibraryItem(name: "Apple Pay", systemImage: "applelogo", color: .black),
        LibraryItem(name: "Visa", systemImage: "creditcard.fill", color: .blue),
        LibraryItem(name: "Mastercard", systemImage: "creditcard.fill", color: .orange),
        LibraryItem(name: "Amex", systemImage: "creditcard.fill", color: .teal),
        LibraryItem(name: "Discover", systemImage: "creditcard.fill", color: .orange),
        LibraryItem(name: "Chase", systemImage: "building.columns.fill", color: .blue),
        LibraryItem(name: "Bank of America", systemImage: "building.columns.fill", color: .red),
        LibraryItem(name: "Wells Fargo", systemImage: "building.columns.fill", color: .red),
        LibraryItem(name: "Capital One", systemImage: "creditcard.fill", color: .red),
        LibraryItem(name: "Citi", systemImage: "building.columns.fill", color: .blue),
        LibraryItem(name: "Debit Card", systemImage: "creditcard.fill", color: .gray),
        LibraryItem(name: "Cash", systemImage: "banknote.fill", color: .green),
    ]

    /// Looks up a library item by exact (case-insensitive) name.
    static func item(named name: String) -> LibraryItem? {
        items.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }
}
