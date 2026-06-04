import SwiftUI

/// A pickable library entry (merchant or card) shown as an icon tile with a name.
///
/// `systemImage` is an SF Symbol used as the icon (real brand logos are trademarked and not
/// bundled). `assetName` is an optional asset-catalog image: if that image exists it's shown
/// instead of the symbol, so licensed logos can be dropped in later without code changes.
struct LibraryItem: Identifiable {
    var id: String { name }
    let name: String
    let systemImage: String
    let color: Color
    /// Optional asset-catalog image name for a real logo (preferred over everything when present).
    let assetName: String?
    /// Optional domain used to fetch a real logo at runtime (overrides the name-derived domain).
    let domain: String?

    init(name: String, systemImage: String, color: Color, assetName: String? = nil, domain: String? = nil) {
        self.name = name
        self.systemImage = systemImage
        self.color = color
        self.assetName = assetName
        self.domain = domain
    }
}

/// Common merchants offered in the merchant picker.
enum MerchantLibrary {
    static let items: [LibraryItem] = [
        // Tech & online
        LibraryItem(name: "Apple", systemImage: "applelogo", color: .black),
        LibraryItem(name: "Amazon", systemImage: "shippingbox.fill", color: .orange),
        LibraryItem(name: "eBay", systemImage: "bag.fill", color: .blue),
        LibraryItem(name: "Etsy", systemImage: "bag.fill", color: .orange),
        LibraryItem(name: "AliExpress", systemImage: "shippingbox.fill", color: .red),
        LibraryItem(name: "Temu", systemImage: "shippingbox.fill", color: .orange),
        LibraryItem(name: "Wayfair", systemImage: "sofa.fill", color: .purple),
        LibraryItem(name: "Google", systemImage: "magnifyingglass", color: .blue),
        LibraryItem(name: "Microsoft", systemImage: "square.grid.2x2.fill", color: .blue),
        LibraryItem(name: "Adobe", systemImage: "a.square.fill", color: .red),
        LibraryItem(name: "Notion", systemImage: "doc.fill", color: .black),
        LibraryItem(name: "Slack", systemImage: "number", color: .purple),
        LibraryItem(name: "Zoom", systemImage: "video.fill", color: .blue),
        LibraryItem(name: "iCloud", systemImage: "icloud.fill", color: .blue),
        LibraryItem(name: "Claude", systemImage: "sparkles", color: .orange),
        LibraryItem(name: "LinkedIn", systemImage: "briefcase.fill", color: .blue),
        // Coffee
        LibraryItem(name: "Starbucks", systemImage: "cup.and.saucer.fill", color: .green),
        LibraryItem(name: "Dunkin'", systemImage: "cup.and.saucer.fill", color: .orange),
        LibraryItem(name: "Peet's Coffee", systemImage: "cup.and.saucer.fill", color: .brown),
        LibraryItem(name: "Philz Coffee", systemImage: "cup.and.saucer.fill", color: .blue),
        LibraryItem(name: "Blue Bottle", systemImage: "cup.and.saucer.fill", color: .blue),
        LibraryItem(name: "Dutch Bros", systemImage: "cup.and.saucer.fill", color: .blue),
        // Groceries
        LibraryItem(name: "Whole Foods", systemImage: "leaf.fill", color: .green),
        LibraryItem(name: "Trader Joe's", systemImage: "cart.fill", color: .red),
        LibraryItem(name: "Safeway", systemImage: "cart.fill", color: .red),
        LibraryItem(name: "Kroger", systemImage: "cart.fill", color: .blue),
        LibraryItem(name: "Costco", systemImage: "cart.fill", color: .blue),
        LibraryItem(name: "Aldi", systemImage: "cart.fill", color: .blue),
        LibraryItem(name: "Publix", systemImage: "cart.fill", color: .green),
        LibraryItem(name: "Sprouts", systemImage: "leaf.fill", color: .green),
        LibraryItem(name: "Instacart", systemImage: "cart.fill", color: .green),
        // Retail
        LibraryItem(name: "Target", systemImage: "target", color: .red),
        LibraryItem(name: "Walmart", systemImage: "cart.fill", color: .blue),
        LibraryItem(name: "Best Buy", systemImage: "desktopcomputer", color: .blue),
        LibraryItem(name: "Home Depot", systemImage: "hammer.fill", color: .orange),
        LibraryItem(name: "Lowe's", systemImage: "hammer.fill", color: .blue),
        LibraryItem(name: "IKEA", systemImage: "sofa.fill", color: .blue),
        LibraryItem(name: "Macy's", systemImage: "bag.fill", color: .red),
        LibraryItem(name: "Nordstrom", systemImage: "bag.fill", color: .black),
        LibraryItem(name: "Sephora", systemImage: "sparkles", color: .black),
        LibraryItem(name: "Ulta", systemImage: "sparkles", color: .orange),
        // Apparel
        LibraryItem(name: "Nike", systemImage: "figure.run", color: .black),
        LibraryItem(name: "Adidas", systemImage: "figure.run", color: .black),
        LibraryItem(name: "Lululemon", systemImage: "figure.run", color: .red),
        LibraryItem(name: "H&M", systemImage: "tshirt.fill", color: .red),
        LibraryItem(name: "Zara", systemImage: "tshirt.fill", color: .black),
        LibraryItem(name: "Uniqlo", systemImage: "tshirt.fill", color: .red),
        LibraryItem(name: "Gap", systemImage: "tshirt.fill", color: .blue),
        LibraryItem(name: "Shein", systemImage: "tshirt.fill", color: .black),
        // Dining
        LibraryItem(name: "Chipotle", systemImage: "fork.knife", color: .red),
        LibraryItem(name: "McDonald's", systemImage: "fork.knife", color: .yellow),
        LibraryItem(name: "Subway", systemImage: "fork.knife", color: .green),
        LibraryItem(name: "Taco Bell", systemImage: "fork.knife", color: .purple),
        LibraryItem(name: "Burger King", systemImage: "fork.knife", color: .orange),
        LibraryItem(name: "Wendy's", systemImage: "fork.knife", color: .red),
        LibraryItem(name: "Chick-fil-A", systemImage: "fork.knife", color: .red),
        LibraryItem(name: "Domino's", systemImage: "fork.knife", color: .blue),
        LibraryItem(name: "Panera", systemImage: "fork.knife", color: .green),
        LibraryItem(name: "Sweetgreen", systemImage: "leaf.fill", color: .green),
        LibraryItem(name: "In-N-Out", systemImage: "fork.knife", color: .red),
        LibraryItem(name: "Five Guys", systemImage: "fork.knife", color: .red),
        LibraryItem(name: "Shake Shack", systemImage: "fork.knife", color: .green),
        // Delivery
        LibraryItem(name: "DoorDash", systemImage: "bag.fill", color: .red),
        LibraryItem(name: "Uber Eats", systemImage: "bag.fill", color: .green),
        LibraryItem(name: "Grubhub", systemImage: "bag.fill", color: .red),
        LibraryItem(name: "Snackpass", systemImage: "fork.knife", color: .yellow),
        // Transport & gas
        LibraryItem(name: "Uber", systemImage: "car.fill", color: .black),
        LibraryItem(name: "Lyft", systemImage: "car.fill", color: .pink),
        LibraryItem(name: "Shell", systemImage: "fuelpump.fill", color: .yellow),
        LibraryItem(name: "Chevron", systemImage: "fuelpump.fill", color: .blue),
        LibraryItem(name: "Exxon", systemImage: "fuelpump.fill", color: .red),
        LibraryItem(name: "BP", systemImage: "fuelpump.fill", color: .green),
        LibraryItem(name: "Arco", systemImage: "fuelpump.fill", color: .blue),
        // Entertainment
        LibraryItem(name: "Netflix", systemImage: "play.rectangle.fill", color: .red),
        LibraryItem(name: "Spotify", systemImage: "music.note", color: .green),
        LibraryItem(name: "Hulu", systemImage: "play.tv.fill", color: .green),
        LibraryItem(name: "Disney+", systemImage: "play.tv.fill", color: .blue),
        LibraryItem(name: "Max", systemImage: "play.tv.fill", color: .purple),
        LibraryItem(name: "YouTube", systemImage: "play.rectangle.fill", color: .red),
        LibraryItem(name: "Apple Music", systemImage: "music.note", color: .pink),
        LibraryItem(name: "Audible", systemImage: "headphones", color: .orange),
        LibraryItem(name: "Steam", systemImage: "gamecontroller.fill", color: .blue),
        LibraryItem(name: "PlayStation", systemImage: "gamecontroller.fill", color: .blue),
        LibraryItem(name: "Xbox", systemImage: "gamecontroller.fill", color: .green),
        LibraryItem(name: "Nintendo", systemImage: "gamecontroller.fill", color: .red),
        LibraryItem(name: "AMC Theatres", systemImage: "film.fill", color: .red),
        LibraryItem(name: "Ticketmaster", systemImage: "ticket.fill", color: .blue),
        // Health & fitness
        LibraryItem(name: "CVS", systemImage: "cross.case.fill", color: .red),
        LibraryItem(name: "Walgreens", systemImage: "cross.case.fill", color: .red),
        LibraryItem(name: "Rite Aid", systemImage: "cross.case.fill", color: .blue),
        LibraryItem(name: "Planet Fitness", systemImage: "dumbbell.fill", color: .purple),
        LibraryItem(name: "Equinox", systemImage: "dumbbell.fill", color: .black),
        LibraryItem(name: "Peloton", systemImage: "bicycle", color: .red),
        // Travel
        LibraryItem(name: "Airbnb", systemImage: "house.fill", color: .pink),
        LibraryItem(name: "Marriott", systemImage: "bed.double.fill", color: .red),
        LibraryItem(name: "Hilton", systemImage: "bed.double.fill", color: .blue),
        LibraryItem(name: "United", systemImage: "airplane", color: .blue),
        LibraryItem(name: "Delta", systemImage: "airplane", color: .red),
        LibraryItem(name: "American Airlines", systemImage: "airplane", color: .blue),
        LibraryItem(name: "Southwest", systemImage: "airplane", color: .blue),
        LibraryItem(name: "Alaska Airlines", systemImage: "airplane", color: .teal),
        // Telecom & utilities
        LibraryItem(name: "AT&T", systemImage: "antenna.radiowaves.left.and.right", color: .blue),
        LibraryItem(name: "Verizon", systemImage: "antenna.radiowaves.left.and.right", color: .red),
        LibraryItem(name: "T-Mobile", systemImage: "antenna.radiowaves.left.and.right", color: .pink),
        LibraryItem(name: "Xfinity", systemImage: "wifi", color: .blue),
        LibraryItem(name: "PG&E", systemImage: "bolt.fill", color: .blue),
        // Money
        LibraryItem(name: "PayPal", systemImage: "dollarsign.circle.fill", color: .blue),
        LibraryItem(name: "Venmo", systemImage: "dollarsign.circle.fill", color: .blue),
        LibraryItem(name: "Cash App", systemImage: "dollarsign.circle.fill", color: .green),
        LibraryItem(name: "Robinhood", systemImage: "chart.line.uptrend.xyaxis", color: .green),
        LibraryItem(name: "Coinbase", systemImage: "bitcoinsign.circle.fill", color: .blue),
    ]

    /// Looks up a library item by exact (case-insensitive) name.
    static func item(named name: String) -> LibraryItem? {
        items.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }
}

/// Common cards/payment methods offered in the card picker.
///
/// Each branded card carries a `domain` so `LogoProvider` fetches the real bank/network logo.
/// Generic entries ("Debit Card", "Cash") have no domain and keep their SF Symbol tiles.
enum CardLibrary {
    static let items: [LibraryItem] = [
        LibraryItem(name: "Apple Card", systemImage: "creditcard.fill", color: .black, domain: "apple.com"),
        LibraryItem(name: "Apple Pay", systemImage: "applelogo", color: .black, domain: "apple.com"),
        LibraryItem(name: "Apple Cash", systemImage: "dollarsign.circle.fill", color: .green, domain: "apple.com"),
        LibraryItem(name: "Visa", systemImage: "creditcard.fill", color: .blue, domain: "visa.com"),
        LibraryItem(name: "Mastercard", systemImage: "creditcard.fill", color: .orange, domain: "mastercard.com"),
        LibraryItem(name: "Amex", systemImage: "creditcard.fill", color: .teal, domain: "americanexpress.com"),
        LibraryItem(name: "Amex Gold", systemImage: "creditcard.fill", color: .yellow, domain: "americanexpress.com"),
        LibraryItem(name: "Amex Platinum", systemImage: "creditcard.fill", color: .gray, domain: "americanexpress.com"),
        LibraryItem(name: "Discover", systemImage: "creditcard.fill", color: .orange, domain: "discover.com"),
        LibraryItem(name: "Chase", systemImage: "building.columns.fill", color: .blue, domain: "chase.com"),
        LibraryItem(name: "Chase Sapphire", systemImage: "creditcard.fill", color: .indigo, domain: "chase.com"),
        LibraryItem(name: "Bank of America", systemImage: "building.columns.fill", color: .red, domain: "bankofamerica.com"),
        LibraryItem(name: "Wells Fargo", systemImage: "building.columns.fill", color: .red, domain: "wellsfargo.com"),
        LibraryItem(name: "Capital One", systemImage: "creditcard.fill", color: .red, domain: "capitalone.com"),
        LibraryItem(name: "Citi", systemImage: "building.columns.fill", color: .blue, domain: "citi.com"),
        LibraryItem(name: "US Bank", systemImage: "building.columns.fill", color: .blue, domain: "usbank.com"),
        LibraryItem(name: "PNC", systemImage: "building.columns.fill", color: .orange, domain: "pnc.com"),
        LibraryItem(name: "TD Bank", systemImage: "building.columns.fill", color: .green, domain: "td.com"),
        LibraryItem(name: "Truist", systemImage: "building.columns.fill", color: .purple, domain: "truist.com"),
        LibraryItem(name: "Ally", systemImage: "building.columns.fill", color: .purple, domain: "ally.com"),
        LibraryItem(name: "Barclays", systemImage: "building.columns.fill", color: .blue, domain: "barclays.com"),
        LibraryItem(name: "Synchrony", systemImage: "creditcard.fill", color: .yellow, domain: "synchrony.com"),
        LibraryItem(name: "Robinhood", systemImage: "chart.line.uptrend.xyaxis", color: .green, domain: "robinhood.com"),
        LibraryItem(name: "Robinhood Gold", systemImage: "creditcard.fill", color: .yellow, domain: "robinhood.com"),
        LibraryItem(name: "SoFi", systemImage: "building.columns.fill", color: .blue, domain: "sofi.com"),
        LibraryItem(name: "Chime", systemImage: "creditcard.fill", color: .green, domain: "chime.com"),
        LibraryItem(name: "Navy Federal", systemImage: "building.columns.fill", color: .blue, domain: "navyfederal.org"),
        LibraryItem(name: "USAA", systemImage: "building.columns.fill", color: .blue, domain: "usaa.com"),
        LibraryItem(name: "Fidelity", systemImage: "chart.pie.fill", color: .green, domain: "fidelity.com"),
        LibraryItem(name: "Charles Schwab", systemImage: "chart.pie.fill", color: .blue, domain: "schwab.com"),
        LibraryItem(name: "Bilt", systemImage: "building.2.fill", color: .black, domain: "biltrewards.com"),
        LibraryItem(name: "Venmo", systemImage: "dollarsign.circle.fill", color: .blue, domain: "venmo.com"),
        LibraryItem(name: "PayPal", systemImage: "dollarsign.circle.fill", color: .blue, domain: "paypal.com"),
        LibraryItem(name: "Cash App", systemImage: "dollarsign.circle.fill", color: .green, domain: "cash.app"),
        LibraryItem(name: "Debit Card", systemImage: "creditcard.fill", color: .gray),
        LibraryItem(name: "Cash", systemImage: "banknote.fill", color: .green),
    ]

    /// Looks up a library item by exact (case-insensitive) name.
    static func item(named name: String) -> LibraryItem? {
        items.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }
}
