import Foundation

/// Resolves real logo image URLs for merchants (and any library item with a known domain).
///
/// Logos are fetched at runtime from Google's keyless favicon service by domain (e.g.
/// "starbucks.com"). An item's explicit `domain` wins; otherwise the merchant name is matched
/// against `knownDomains` below. Items with no resolvable domain return `nil`, so callers fall
/// back to the bundled asset or the colored SF Symbol.
///
/// Tradeoff: this makes a network request per known merchant to render its logo, so logo art is no
/// longer strictly on-device. The lookup uses a fixed, public merchant list (not the user's data),
/// and failed/blocked fetches degrade gracefully to the SF Symbol.
enum LogoProvider {
    /// High-quality primary logo (Clearbit's logo service, by domain), or `nil` when no domain is
    /// known. Returns a large, mostly-square brand logo, much sharper than a favicon.
    /// - Parameter item: The merchant/card library item.
    static func logoURL(for item: LibraryItem) -> URL? {
        guard let domain = domain(for: item) else { return nil }
        return URL(string: "https://logo.clearbit.com/\(domain)?size=256")
    }

    /// Higher-quality fallback icon, used only when the primary logo fails to load. icon.horse
    /// returns the site's apple-touch-icon when present (typically 180–512px), which is far
    /// sharper than a 16–64px favicon.
    /// - Parameter item: The merchant/card library item.
    static func fallbackURL(for item: LibraryItem) -> URL? {
        guard let domain = domain(for: item) else { return nil }
        return URL(string: "https://icon.horse/icon/\(domain)")
    }

    /// Resolves a domain for the item: its explicit `domain`, else a name match in `knownDomains`.
    private static func domain(for item: LibraryItem) -> String? {
        if let explicit = item.domain, !explicit.isEmpty { return explicit }
        return knownDomains[item.name.lowercased()]
    }

    /// Maps known merchant names (lowercased, as listed in `MerchantLibrary`) to their domain so the
    /// favicon service returns the brand's logo. Extend this freely to add more logos.
    private static let knownDomains: [String: String] = [
        // Tech & online
        "apple": "apple.com", "amazon": "amazon.com", "ebay": "ebay.com", "etsy": "etsy.com",
        "aliexpress": "aliexpress.com", "temu": "temu.com", "wayfair": "wayfair.com",
        "google": "google.com", "microsoft": "microsoft.com", "adobe": "adobe.com",
        "notion": "notion.so", "slack": "slack.com", "zoom": "zoom.us",
        "icloud": "icloud.com", "claude": "claude.ai", "linkedin": "linkedin.com",
        // Coffee
        "starbucks": "starbucks.com", "dunkin'": "dunkindonuts.com", "peet's coffee": "peets.com",
        "philz coffee": "philzcoffee.com", "blue bottle": "bluebottlecoffee.com",
        "dutch bros": "dutchbros.com",
        // Groceries
        "whole foods": "wholefoodsmarket.com", "trader joe's": "traderjoes.com",
        "safeway": "safeway.com", "kroger": "kroger.com", "costco": "costco.com",
        "aldi": "aldi.us", "publix": "publix.com", "sprouts": "sprouts.com",
        "instacart": "instacart.com",
        // Retail
        "target": "target.com", "walmart": "walmart.com", "best buy": "bestbuy.com",
        "home depot": "homedepot.com", "lowe's": "lowes.com", "ikea": "ikea.com",
        "macy's": "macys.com", "nordstrom": "nordstrom.com", "sephora": "sephora.com",
        "ulta": "ulta.com",
        // Apparel
        "nike": "nike.com", "adidas": "adidas.com", "lululemon": "lululemon.com",
        "h&m": "hm.com", "zara": "zara.com", "uniqlo": "uniqlo.com", "gap": "gap.com",
        "shein": "shein.com",
        // Dining
        "chipotle": "chipotle.com", "mcdonald's": "mcdonalds.com", "subway": "subway.com",
        "taco bell": "tacobell.com", "burger king": "bk.com", "wendy's": "wendys.com",
        "chick-fil-a": "chick-fil-a.com", "domino's": "dominos.com", "panera": "panerabread.com",
        "sweetgreen": "sweetgreen.com", "in-n-out": "in-n-out.com", "five guys": "fiveguys.com",
        "shake shack": "shakeshack.com",
        // Delivery
        "doordash": "doordash.com", "uber eats": "ubereats.com", "grubhub": "grubhub.com",
        "snackpass": "snackpass.co",
        // Transport & gas
        "uber": "uber.com", "lyft": "lyft.com", "shell": "shell.com", "chevron": "chevron.com",
        "exxon": "exxon.com", "bp": "bp.com", "arco": "arco.com",
        // Entertainment
        "netflix": "netflix.com", "spotify": "spotify.com", "hulu": "hulu.com",
        "disney+": "disneyplus.com", "max": "max.com", "youtube": "youtube.com",
        "apple music": "apple.com", "audible": "audible.com", "steam": "steampowered.com",
        "playstation": "playstation.com", "xbox": "xbox.com", "nintendo": "nintendo.com",
        "amc theatres": "amctheatres.com", "ticketmaster": "ticketmaster.com",
        // Health & fitness
        "cvs": "cvs.com", "walgreens": "walgreens.com", "rite aid": "riteaid.com",
        "planet fitness": "planetfitness.com", "equinox": "equinox.com", "peloton": "onepeloton.com",
        // Travel
        "airbnb": "airbnb.com", "marriott": "marriott.com", "hilton": "hilton.com",
        "united": "united.com", "delta": "delta.com", "american airlines": "aa.com",
        "southwest": "southwest.com", "alaska airlines": "alaskaair.com",
        // Telecom & utilities
        "at&t": "att.com", "verizon": "verizon.com", "t-mobile": "t-mobile.com",
        "xfinity": "xfinity.com", "pg&e": "pge.com",
        // Money
        "paypal": "paypal.com", "venmo": "venmo.com", "cash app": "cash.app",
        "robinhood": "robinhood.com", "coinbase": "coinbase.com"
    ]
}
