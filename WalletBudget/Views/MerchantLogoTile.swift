import SwiftUI
import UIKit

/// The merchant logo tile shared by the Recent tab, the By-merchant group rows, and the Repeat
/// list so a given merchant always renders the *same* tile everywhere.
///
/// Resolution order (matches the original Recent-tab behavior):
/// 1. Bundled asset-catalog logo, when one exists for the merchant.
/// 2. A runtime-fetched logo URL, when `LogoProvider` supplies one (currently always `nil`).
/// 3. A colored SF Symbol fallback derived from the merchant's library entry.
///
/// The tile always represents the *merchant* (never the spending category). Unknown merchants get
/// a neutral gray "bag" symbol rather than a category icon, so Recent and By-merchant agree.
struct MerchantLogoTile: View {
    /// Merchant name to render a tile for (e.g. "Blue Bottle"). Empty/unknown names fall back.
    let merchant: String
    /// Side length of the square tile in points.
    var size: CGFloat = 44
    /// Corner radius of the tile's rounded-rectangle clip.
    var cornerRadius: CGFloat = 10

    /// The merchant's library entry, or a generic gray fallback so the tile always represents the
    /// merchant (never the category). Mirrors the fallback the Recent tab has always used.
    private var item: LibraryItem {
        MerchantLibrary.item(named: merchant)
            ?? LibraryItem(name: merchant, systemImage: "bag.fill", color: .gray)
    }

    var body: some View {
        Group {
            if let asset = item.assetName, UIImage(named: asset) != nil {
                imageTile { Image(asset).resizable().scaledToFill() }
            } else if let primary = LogoProvider.logoURL(for: item) {
                AsyncImage(url: primary) { phase in
                    if case .success(let image) = phase {
                        imageTile { image.resizable().scaledToFill() }
                    } else if let fallback = LogoProvider.fallbackURL(for: item) {
                        AsyncImage(url: fallback) { fallbackPhase in
                            if case .success(let image) = fallbackPhase {
                                imageTile { image.resizable().scaledToFill() }
                            } else {
                                symbolTile
                            }
                        }
                    } else {
                        symbolTile
                    }
                }
            } else {
                symbolTile
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// A tile hosting a logo image that fills the whole squircle (no inset). The white backing only
    /// shows through any transparent edges of the artwork. Both layers are pinned to the tile size
    /// so they cover the full squircle edge-to-edge (no uncovered corners).
    private func imageTile<Content: View>(@ViewBuilder _ image: () -> Content) -> some View {
        ZStack {
            Color.white
            image()
                .frame(width: size, height: size)
                .clipped()
        }
        .frame(width: size, height: size)
    }

    /// The colored SF Symbol fallback tile, sized proportionally to the tile. The gradient fill is
    /// pinned to the tile size so it covers the entire squircle.
    private var symbolTile: some View {
        ZStack {
            Rectangle().fill(item.color.gradient)
            Image(systemName: item.systemImage)
                .font(.system(size: size * 0.41, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 16) {
        MerchantLogoTile(merchant: "Starbucks")
        MerchantLogoTile(merchant: "Joe's Diner")
        MerchantLogoTile(merchant: "Netflix", size: 38, cornerRadius: 9)
    }
    .padding()
}
