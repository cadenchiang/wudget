import SwiftUI

/// A pickable library entry (merchant or card) shown as an icon tile with a name.
///
/// `systemImage` is an SF Symbol fallback icon. `assetName` is the asset-catalog image for the
/// brand's real logo: when not passed explicitly it defaults to the name-derived
/// `bundledLogoName(for:)` ("logo_<slug>"), so every known brand renders its bundled logo
/// instantly with no network fetch. Callers check `UIImage(named:)` before using it, so names
/// with no matching asset (unknown merchants, "Cash") fall back to the runtime logo or symbol.
struct LibraryItem: Identifiable {
    var id: String { name }
    let name: String
    let systemImage: String
    let color: Color
    /// Asset-catalog image name for the brand logo (preferred over everything when present).
    let assetName: String?
    /// Optional domain used to fetch a real logo at runtime (overrides the name-derived domain).
    let domain: String?

    init(name: String, systemImage: String, color: Color, assetName: String? = nil, domain: String? = nil) {
        self.name = name
        self.systemImage = systemImage
        self.color = color
        self.assetName = assetName ?? LibraryItem.bundledLogoName(for: name)
        self.domain = domain
    }

    /// Asset-catalog name for a brand's bundled logo: "logo_" plus the lowercased name with every
    /// run of non-alphanumerics collapsed to a single underscore and edges trimmed
    /// (e.g. "Peet's Coffee" → "logo_peet_s_coffee", "Chick-fil-A" → "logo_chick_fil_a").
    /// Must stay in sync with the slug rule used to generate the logo imagesets.
    static func bundledLogoName(for name: String) -> String {
        var slug = ""
        var lastWasSeparator = true // trims leading separators
        for character in name.lowercased() {
            if character.isLetter || character.isNumber {
                slug.append(character)
                lastWasSeparator = false
            } else if !lastWasSeparator {
                slug.append("_")
                lastWasSeparator = true
            }
        }
        if slug.hasSuffix("_") { slug.removeLast() }
        return "logo_" + slug
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
        // Dining II
        LibraryItem(name: "Panda Express", systemImage: "fork.knife", color: .red),
        LibraryItem(name: "Raising Cane's", systemImage: "fork.knife", color: .red),
        LibraryItem(name: "Wingstop", systemImage: "fork.knife", color: .green),
        LibraryItem(name: "KFC", systemImage: "fork.knife", color: .red),
        LibraryItem(name: "Popeyes", systemImage: "fork.knife", color: .orange),
        LibraryItem(name: "Sonic", systemImage: "fork.knife", color: .blue),
        LibraryItem(name: "Dairy Queen", systemImage: "fork.knife", color: .red),
        LibraryItem(name: "Cava", systemImage: "fork.knife", color: .orange),
        LibraryItem(name: "Jersey Mike's", systemImage: "fork.knife", color: .blue),
        LibraryItem(name: "Jimmy John's", systemImage: "fork.knife", color: .red),
        LibraryItem(name: "Crumbl", systemImage: "birthday.cake.fill", color: .pink),
        LibraryItem(name: "Insomnia Cookies", systemImage: "birthday.cake.fill", color: .purple),
        LibraryItem(name: "Jamba", systemImage: "cup.and.saucer.fill", color: .orange),
        LibraryItem(name: "Smoothie King", systemImage: "cup.and.saucer.fill", color: .red),
        LibraryItem(name: "Olive Garden", systemImage: "fork.knife", color: .green),
        LibraryItem(name: "Chili's", systemImage: "fork.knife", color: .red),
        LibraryItem(name: "Buffalo Wild Wings", systemImage: "fork.knife", color: .yellow),
        // Convenience & gas II
        LibraryItem(name: "7-Eleven", systemImage: "cart.fill", color: .orange),
        LibraryItem(name: "Wawa", systemImage: "cart.fill", color: .red),
        LibraryItem(name: "Circle K", systemImage: "fuelpump.fill", color: .red),
        LibraryItem(name: "Speedway", systemImage: "fuelpump.fill", color: .blue),
        LibraryItem(name: "QuikTrip", systemImage: "fuelpump.fill", color: .red),
        LibraryItem(name: "Valero", systemImage: "fuelpump.fill", color: .blue),
        // Groceries II
        LibraryItem(name: "H-E-B", systemImage: "cart.fill", color: .red),
        LibraryItem(name: "Wegmans", systemImage: "cart.fill", color: .green),
        LibraryItem(name: "Meijer", systemImage: "cart.fill", color: .blue),
        LibraryItem(name: "Albertsons", systemImage: "cart.fill", color: .blue),
        LibraryItem(name: "Sam's Club", systemImage: "cart.fill", color: .blue),
        LibraryItem(name: "BJ's", systemImage: "cart.fill", color: .red),
        // Retail II
        LibraryItem(name: "TJ Maxx", systemImage: "bag.fill", color: .red),
        LibraryItem(name: "Marshalls", systemImage: "bag.fill", color: .blue),
        LibraryItem(name: "Ross", systemImage: "bag.fill", color: .blue),
        LibraryItem(name: "Dollar Tree", systemImage: "bag.fill", color: .green),
        LibraryItem(name: "Dollar General", systemImage: "bag.fill", color: .yellow),
        LibraryItem(name: "Five Below", systemImage: "bag.fill", color: .blue),
        LibraryItem(name: "GameStop", systemImage: "gamecontroller.fill", color: .red),
        LibraryItem(name: "Dick's Sporting Goods", systemImage: "figure.run", color: .green),
        LibraryItem(name: "REI", systemImage: "tent.fill", color: .green),
        LibraryItem(name: "Staples", systemImage: "paperclip", color: .red),
        LibraryItem(name: "Michaels", systemImage: "paintpalette.fill", color: .red),
        LibraryItem(name: "PetSmart", systemImage: "pawprint.fill", color: .blue),
        LibraryItem(name: "Petco", systemImage: "pawprint.fill", color: .blue),
        LibraryItem(name: "AutoZone", systemImage: "car.fill", color: .red),
        // Tech & subscriptions II
        LibraryItem(name: "OpenAI", systemImage: "sparkles", color: .black),
        LibraryItem(name: "GitHub", systemImage: "chevron.left.forwardslash.chevron.right", color: .black),
        LibraryItem(name: "Dropbox", systemImage: "shippingbox.fill", color: .blue),
        LibraryItem(name: "Discord", systemImage: "bubble.left.and.bubble.right.fill", color: .indigo),
        LibraryItem(name: "Twitch", systemImage: "play.tv.fill", color: .purple),
        LibraryItem(name: "Patreon", systemImage: "heart.fill", color: .orange),
        LibraryItem(name: "Canva", systemImage: "paintbrush.fill", color: .teal),
        LibraryItem(name: "Figma", systemImage: "square.on.square", color: .purple),
        LibraryItem(name: "Duolingo", systemImage: "graduationcap.fill", color: .green),
        LibraryItem(name: "Chegg", systemImage: "book.fill", color: .orange),
        LibraryItem(name: "Quizlet", systemImage: "book.fill", color: .indigo),
        LibraryItem(name: "Paramount+", systemImage: "play.tv.fill", color: .blue),
        LibraryItem(name: "Peacock", systemImage: "play.tv.fill", color: .black),
        LibraryItem(name: "Crunchyroll", systemImage: "play.tv.fill", color: .orange),
        // Travel & transport II
        LibraryItem(name: "Lime", systemImage: "scooter", color: .green),
        LibraryItem(name: "Amtrak", systemImage: "tram.fill", color: .blue),
        LibraryItem(name: "JetBlue", systemImage: "airplane", color: .blue),
        LibraryItem(name: "Spirit", systemImage: "airplane", color: .yellow),
        LibraryItem(name: "Turo", systemImage: "car.fill", color: .purple),
        LibraryItem(name: "Hertz", systemImage: "car.fill", color: .yellow),
        LibraryItem(name: "Enterprise", systemImage: "car.fill", color: .green),
        LibraryItem(name: "Fandango", systemImage: "film.fill", color: .orange),
        LibraryItem(name: "Regal", systemImage: "film.fill", color: .red),
        LibraryItem(name: "Cinemark", systemImage: "film.fill", color: .red),
        LibraryItem(name: "Topgolf", systemImage: "figure.golf", color: .blue),
        LibraryItem(name: "ClassPass", systemImage: "dumbbell.fill", color: .blue),
        LibraryItem(name: "Orangetheory", systemImage: "dumbbell.fill", color: .orange),
        LibraryItem(name: "LA Fitness", systemImage: "dumbbell.fill", color: .purple),
        LibraryItem(name: "UPS", systemImage: "shippingbox.fill", color: .brown),
        LibraryItem(name: "FedEx", systemImage: "shippingbox.fill", color: .purple),
        LibraryItem(name: "USPS", systemImage: "envelope.fill", color: .blue),
        LibraryItem(name: "Klarna", systemImage: "creditcard.fill", color: .pink),
        LibraryItem(name: "Afterpay", systemImage: "creditcard.fill", color: .teal),
        LibraryItem(name: "Affirm", systemImage: "creditcard.fill", color: .indigo),
        LibraryItem(name: "Zelle", systemImage: "dollarsign.circle.fill", color: .purple),
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
        // Banks, cards, and fintechs II
        LibraryItem(name: "Chase Freedom", systemImage: "creditcard.fill", color: .blue, domain: "chase.com"),
        LibraryItem(name: "Chase Sapphire Reserve", systemImage: "creditcard.fill", color: .indigo, domain: "chase.com"),
        LibraryItem(name: "Amex Blue Cash", systemImage: "creditcard.fill", color: .blue, domain: "americanexpress.com"),
        LibraryItem(name: "Citi Double Cash", systemImage: "creditcard.fill", color: .blue, domain: "citi.com"),
        LibraryItem(name: "Discover it", systemImage: "creditcard.fill", color: .orange, domain: "discover.com"),
        LibraryItem(name: "Wells Fargo Active Cash", systemImage: "creditcard.fill", color: .red, domain: "wellsfargo.com"),
        LibraryItem(name: "Capital One Venture", systemImage: "creditcard.fill", color: .red, domain: "capitalone.com"),
        LibraryItem(name: "Capital One Quicksilver", systemImage: "creditcard.fill", color: .gray, domain: "capitalone.com"),
        LibraryItem(name: "Capital One Savor", systemImage: "creditcard.fill", color: .orange, domain: "capitalone.com"),
        LibraryItem(name: "Prime Visa", systemImage: "creditcard.fill", color: .blue, domain: "amazon.com"),
        LibraryItem(name: "Target Circle Card", systemImage: "creditcard.fill", color: .red, domain: "target.com"),
        LibraryItem(name: "Costco Anywhere", systemImage: "creditcard.fill", color: .blue, domain: "costco.com"),
        LibraryItem(name: "Best Buy Card", systemImage: "creditcard.fill", color: .blue, domain: "bestbuy.com"),
        LibraryItem(name: "Marcus", systemImage: "building.columns.fill", color: .blue, domain: "marcus.com"),
        LibraryItem(name: "Goldman Sachs", systemImage: "building.columns.fill", color: .blue, domain: "goldmansachs.com"),
        LibraryItem(name: "Regions", systemImage: "building.columns.fill", color: .green, domain: "regions.com"),
        LibraryItem(name: "Fifth Third", systemImage: "building.columns.fill", color: .blue, domain: "53.com"),
        LibraryItem(name: "KeyBank", systemImage: "building.columns.fill", color: .red, domain: "key.com"),
        LibraryItem(name: "Huntington", systemImage: "building.columns.fill", color: .green, domain: "huntington.com"),
        LibraryItem(name: "M&T Bank", systemImage: "building.columns.fill", color: .green, domain: "mtb.com"),
        LibraryItem(name: "Citizens Bank", systemImage: "building.columns.fill", color: .green, domain: "citizensbank.com"),
        LibraryItem(name: "Santander", systemImage: "building.columns.fill", color: .red, domain: "santanderbank.com"),
        LibraryItem(name: "HSBC", systemImage: "building.columns.fill", color: .red, domain: "hsbc.com"),
        LibraryItem(name: "BMO", systemImage: "building.columns.fill", color: .blue, domain: "bmo.com"),
        LibraryItem(name: "PenFed", systemImage: "building.columns.fill", color: .blue, domain: "penfed.org"),
        LibraryItem(name: "Alliant", systemImage: "building.columns.fill", color: .blue, domain: "alliantcreditunion.org"),
        LibraryItem(name: "Golden 1", systemImage: "building.columns.fill", color: .yellow, domain: "golden1.com"),
        LibraryItem(name: "BECU", systemImage: "building.columns.fill", color: .green, domain: "becu.org"),
        LibraryItem(name: "Greenlight", systemImage: "creditcard.fill", color: .green, domain: "greenlight.com"),
        LibraryItem(name: "Step", systemImage: "creditcard.fill", color: .black, domain: "step.com"),
        LibraryItem(name: "Current", systemImage: "creditcard.fill", color: .purple, domain: "current.com"),
        LibraryItem(name: "Revolut", systemImage: "creditcard.fill", color: .black, domain: "revolut.com"),
        LibraryItem(name: "Wise", systemImage: "creditcard.fill", color: .green, domain: "wise.com"),
        LibraryItem(name: "Varo", systemImage: "creditcard.fill", color: .purple, domain: "varomoney.com"),
        LibraryItem(name: "E*Trade", systemImage: "chart.pie.fill", color: .purple, domain: "etrade.com"),
        LibraryItem(name: "Vanguard", systemImage: "chart.pie.fill", color: .red, domain: "vanguard.com"),
        LibraryItem(name: "Betterment", systemImage: "chart.pie.fill", color: .blue, domain: "betterment.com"),
        LibraryItem(name: "Wealthfront", systemImage: "chart.pie.fill", color: .teal, domain: "wealthfront.com"),
        LibraryItem(name: "Gemini", systemImage: "bitcoinsign.circle.fill", color: .blue, domain: "gemini.com"),
        LibraryItem(name: "Crypto.com", systemImage: "bitcoinsign.circle.fill", color: .indigo, domain: "crypto.com"),
        LibraryItem(name: "Debit Card", systemImage: "creditcard.fill", color: .gray),
        LibraryItem(name: "Cash", systemImage: "banknote.fill", color: .green),
    ]

    /// Looks up a library item by exact (case-insensitive) name.
    static func item(named name: String) -> LibraryItem? {
        items.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }
}
