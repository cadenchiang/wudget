import SwiftUI

/// The amount rendered in a small color-coded squircle: gray for negligible spends, green for
/// everyday amounts, orange for notable ones, red for big-ticket charges.
struct AmountBadge: View {
    let amount: Double

    private var color: Color {
        switch amount {
        case ..<15: return .gray
        case ..<75: return .green
        case ..<200: return .orange
        default: return .red
        }
    }

    var body: some View {
        Text(amount.asCurrency())
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(color))
    }
}

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
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(group.count) Transaction\(group.count == 1 ? "" : "s")")
                    if group.hasComparison {
                        deltaLabel
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            AmountBadge(amount: group.total)
        }
        .padding(.vertical, 14)
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
/// and the color-coded amount badge. Used by the Recent tab so it matches the grouped tabs.
struct TransactionRow: View {
    let expense: Expense

    var body: some View {
        HStack(spacing: 12) {
            MerchantLogoTile(merchant: expense.merchant)
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.merchant.isEmpty ? "Unknown" : expense.merchant)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(expense.date, format: .dateTime.month().day())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            AmountBadge(amount: expense.amount)
        }
        .padding(.vertical, 14)
    }
}

#Preview {
    List {
        SpendingGroupRow(group: GroupTotal(key: "Shopping", total: 1063.56, count: 9, previousTotal: 553.21))
        SpendingGroupRow(group: GroupTotal(key: "Transport", total: 86.50, count: 12, previousTotal: 174.56))
        SpendingGroupRow(group: GroupTotal(key: "Other", total: 26.38, count: 1, previousTotal: 0))
    }
}
