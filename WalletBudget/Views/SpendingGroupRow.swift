import SwiftUI

/// A single grouped-spending row: a colored icon tile, the group name and transaction
/// count, the period total, an optional delta-versus-last-period line, and a chevron.
struct SpendingGroupRow: View {
    let group: GroupTotal
    var grouping: SpendingGrouping = .category

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

    /// The leading tile. When grouping by merchant it's the shared merchant logo (so it matches the
    /// Recent tab); when grouping by category it's the category's colored icon.
    @ViewBuilder
    private var iconTile: some View {
        if grouping == .merchant {
            MerchantLogoTile(merchant: group.key)
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(CategoryStyle.color(for: group.key).gradient)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: CategoryStyle.icon(for: group.key))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
        }
    }

    /// Percentage change versus the previous period (rounded; 0 when no comparison).
    private var percentChange: Int {
        guard group.previousTotal > 0 else { return 0 }
        return Int((group.delta / group.previousTotal * 100).rounded())
    }

    /// Arrow + percentage showing change versus the previous period.
    private var deltaLabel: some View {
        HStack(spacing: 2) {
            Image(systemName: group.delta <= 0 ? "arrow.down" : "arrow.up")
            Text("\(abs(percentChange))%")
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

    var body: some View {
        HStack(spacing: 12) {
            MerchantLogoTile(merchant: expense.merchant)
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
