import SwiftUI

/// A single grouped-spending row: a colored icon tile, the group name and transaction
/// count, the period total, an optional delta-versus-last-period line, and a chevron.
struct SpendingGroupRow: View {
    let group: GroupTotal
    var grouping: SpendingGrouping = .category

    /// Icon for the tile: a known merchant's library icon when grouping by merchant, else the
    /// category icon (with a generic fallback for unknown keys).
    private var iconName: String {
        if grouping == .merchant, let item = MerchantLibrary.item(named: group.key) {
            return item.systemImage
        }
        return CategoryStyle.icon(for: group.key)
    }

    /// Tile color, paired with `iconName`.
    private var iconColor: Color {
        if grouping == .merchant, let item = MerchantLibrary.item(named: group.key) {
            return item.color
        }
        return CategoryStyle.color(for: group.key)
    }

    var body: some View {
        HStack(spacing: 12) {
            iconTile

            VStack(alignment: .leading, spacing: 2) {
                Text(group.key)
                    .font(.body.weight(.semibold))
                Text("\(group.count) Transaction\(group.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(group.total.asCurrency())
                    .font(.body.weight(.semibold))
                if group.hasComparison {
                    deltaLabel
                }
            }

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
    }

    /// The rounded color tile with the category/merchant icon.
    private var iconTile: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(iconColor.gradient)
            .frame(width: 44, height: 44)
            .overlay {
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }

    /// Arrow + amount showing change versus the previous period.
    private var deltaLabel: some View {
        HStack(spacing: 2) {
            Image(systemName: group.delta <= 0 ? "arrow.down" : "arrow.up")
            Text(abs(group.delta).asCurrency())
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

#Preview {
    List {
        SpendingGroupRow(group: GroupTotal(key: "Shopping", total: 1063.56, count: 9, previousTotal: 553.21))
        SpendingGroupRow(group: GroupTotal(key: "Transport", total: 86.50, count: 12, previousTotal: 174.56))
        SpendingGroupRow(group: GroupTotal(key: "Other", total: 26.38, count: 1, previousTotal: 0))
    }
}
