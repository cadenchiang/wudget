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

/// A single transaction row styled like `SpendingGroupRow`: colored icon tile, merchant, date,
/// amount, and a chevron. Used by the Recent tab so it matches the grouped tabs.
struct TransactionRow: View {
    let expense: Expense
    /// Whether to draw the trailing chevron. Off when inside a `List` `NavigationLink`, which
    /// supplies its own chevron (avoids a double chevron).
    var showsChevron: Bool = true

    private var libraryItem: LibraryItem? { MerchantLibrary.item(named: expense.merchant) }
    private var iconName: String { libraryItem?.systemImage ?? CategoryStyle.icon(for: expense.category) }
    private var iconColor: Color { libraryItem?.color ?? CategoryStyle.color(for: expense.category) }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(iconColor.gradient)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.merchant.isEmpty ? "Unknown" : expense.merchant)
                    .font(.body.weight(.semibold))
                Text(expense.date, format: .dateTime.month().day())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(expense.amount.asCurrency())
                .font(.body.weight(.semibold))
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 12)
    }
}

#Preview {
    List {
        SpendingGroupRow(group: GroupTotal(key: "Shopping", total: 1063.56, count: 9, previousTotal: 553.21))
        SpendingGroupRow(group: GroupTotal(key: "Transport", total: 86.50, count: 12, previousTotal: 174.56))
        SpendingGroupRow(group: GroupTotal(key: "Other", total: 26.38, count: 1, previousTotal: 0))
    }
}
