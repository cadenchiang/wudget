import SwiftUI
import Charts

/// A forward-looking pace projection for the current period.
struct SpendingProjection {
    let amount: Double
    let periodNoun: String
    /// Whether the projected amount is within budget; nil when no budget is set.
    let isWithinBudget: Bool?
    /// Budget remaining for the period (budget minus spent so far); nil when no budget is set.
    /// Negative when already over budget.
    let remaining: Double?
    /// Whole days left in the current period (including today).
    let daysRemaining: Int

    /// Green when projected to stay within budget, gray otherwise (or when no budget).
    var amountColor: Color { isWithinBudget == true ? .green : .gray }
}

/// Whether the spending card counts everything or only variable (non-fixed) costs.
enum SpendingMode: String, CaseIterable, Identifiable {
    case total
    case variable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .total: return "Total Spending"
        case .variable: return "Variable Spending"
        }
    }
}

/// The "Total Spending" card: the period total, a comparison line versus the previous
/// period, and a stacked bar chart over the period's time buckets (e.g. 1-7, 8-14 for a
/// month) where each bar is segmented by category color.
///
/// Tapping a bar dims the others and shows an info card with that bucket's total. Tapping
/// empty space clears the selection.
struct TotalSpendingCard: View {
    /// Total spent in the current period.
    let total: Double
    /// Total spent in the previous period (for the comparison line).
    let previousTotal: Double
    /// Per-bucket, per-category segments to stack.
    let segments: [CategorySegment]
    /// Ordered bucket labels (defines the x-axis, including empty buckets).
    let bucketLabels: [String]
    /// Optional forward-looking projection shown under the amount (amount colored by budget).
    let projection: SpendingProjection?
    /// Optional per-bucket budget target; draws a budget line with green/gray gradients.
    let budgetPerBucket: Double?
    /// The current spending mode (drives the title dropdown).
    @Binding var mode: SpendingMode

    @State private var selected: String?

    /// Gray for the budget line and its matching y-axis value label (same color/darkness).
    /// A dark gray in light mode; lighter/whiter in dark mode so it stays visible on either.
    private var budgetColor: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.92, alpha: 1.0)
                : UIColor(white: 0.32, alpha: 1.0)
        })
    }

    /// Whether the period is projected to finish over budget (a budget must be set).
    private var isOverBudget: Bool { projection?.isWithinBudget == false }

    private var delta: Double { total - previousTotal }

    /// Whether there's previous-period spending to compare against.
    private var hasComparison: Bool { previousTotal > 0 }

    /// One-line comparison versus the previous period (only meaningful when `hasComparison`).
    private var comparison: String {
        let direction = delta <= 0 ? "less" : "more"
        return "So far, you've spent \(abs(delta).asCurrency()) \(direction) than last period at this time."
    }

    /// A one-sentence budget summary: how much is left to spend this period (and over how many
    /// days), or how much over budget. The dollar amount is colored green (under) or red (over).
    private func budgetSentence(remaining: Double, periodNoun: String, daysRemaining: Int) -> Text {
        let dayWord = daysRemaining == 1 ? "day" : "days"
        let tail = Text(" with \(daysRemaining) \(dayWord) left this \(periodNoun).").foregroundStyle(.secondary)
        if remaining > 0 {
            return Text("You have ").foregroundStyle(.secondary)
                + Text(remaining.asCurrency()).foregroundStyle(.green)
                + Text(" left to spend").foregroundStyle(.secondary)
                + tail
        } else if remaining < 0 {
            return Text("You're ").foregroundStyle(.secondary)
                + Text(abs(remaining).asCurrency()).foregroundStyle(.red)
                + Text(" over budget").foregroundStyle(.secondary)
                + tail
        } else {
            return Text("You've used your full budget").foregroundStyle(.secondary)
                + tail
        }
    }

    /// Upper bound for the y-axis. Falls back to a fixed value when there's no spending so the
    /// axis (and its baseline above the dates) still renders; otherwise adds a little headroom.
    private var yMax: Double {
        let maxBucket = bucketLabels.map(bucketTotal).max() ?? 0
        let ceiling = max(maxBucket, budgetPerBucket ?? 0)
        return ceiling > 0 ? ceiling * 1.1 : 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Menu {
                Picker("Spending mode", selection: $mode) {
                    ForEach(SpendingMode.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(mode.title)
                        .font(.subheadline)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(.primary)
            }
            .tint(.primary)

            HStack(spacing: 8) {
                Text(total.asCurrency())
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(isOverBudget ? .red : .primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if hasComparison {
                    Image(systemName: delta <= 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .foregroundStyle(delta <= 0 ? .green : .red)
                        .font(.title3)
                }
            }

            if let projection, let remaining = projection.remaining {
                budgetSentence(remaining: remaining, periodNoun: projection.periodNoun, daysRemaining: projection.daysRemaining)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            } else if hasComparison {
                Text(comparison)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            chart
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    /// Stacked, category-colored bars over the time buckets, with a budget line + tap selection.
    private var chart: some View {
        Chart {
            ForEach(segments) { segment in
                BarMark(
                    x: .value("Period", segment.bucketLabel),
                    y: .value("Spent", segment.total)
                )
                .foregroundStyle(CategoryStyle.color(for: segment.category))
                .opacity(opacity(for: segment.bucketLabel))
                .cornerRadius(3)
            }
            if let budgetPerBucket {
                RuleMark(y: .value("Budget", budgetPerBucket))
                    .foregroundStyle(budgetColor)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [2, 4]))
            }
        }
        .chartXScale(domain: bucketLabels)
        .chartYScale(domain: 0...yMax)
        .chartXSelection(value: $selected)
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine()
                // Suppress a regular label when it sits near the budget label, so the budget
                // value always wins and the two numbers don't overlap into a confusing blur.
                if let amount = value.as(Double.self), !isNearBudget(amount) {
                    AxisValueLabel {
                        Text(abbreviatedAmount(amount))
                    }
                }
            }
            if let budgetPerBucket {
                AxisMarks(position: .trailing, values: [budgetPerBucket]) { value in
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(abbreviatedAmount(amount))
                                .foregroundStyle(budgetColor)
                        }
                    }
                }
            }
        }
        .chartBackground { proxy in budgetGradients(proxy) }
        .frame(height: 190)
        .padding(.top, 4)
        .onChange(of: selected) { _, newValue in
            if newValue != nil { Haptics.selection() }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                if let selected,
                   let plotAnchor = proxy.plotFrame,
                   let xPosition = proxy.position(forX: selected) {
                    let plot = geo[plotAnchor]
                    let cardWidth: CGFloat = 150
                    let gap: CGFloat = 18
                    let barX = plot.minX + xPosition
                    // Place the card beside the bar (right if the bar is on the left half, else left)
                    // so it never covers the selected bar.
                    let preferRight = barX < plot.midX
                    let sideX = preferRight ? barX + gap + cardWidth / 2 : barX - gap - cardWidth / 2
                    let clampedX = min(max(sideX, plot.minX + cardWidth / 2), plot.maxX - cardWidth / 2)
                    infoCard(bucket: selected)
                        .frame(width: cardWidth)
                        .position(x: clampedX, y: plot.minY + 30)
                }
            }
        }
    }

    /// Slight gradients split at the budget line: green below (under budget), gray above (over).
    @ViewBuilder
    private func budgetGradients(_ proxy: ChartProxy) -> some View {
        GeometryReader { geo in
            if let budgetPerBucket,
               let plotAnchor = proxy.plotFrame,
               let yPosition = proxy.position(forY: budgetPerBucket) {
                let plot = geo[plotAnchor]
                let lineY = min(max(plot.minY + yPosition, plot.minY), plot.maxY)
                let aboveHeight = lineY - plot.minY
                let belowHeight = plot.maxY - lineY

                LinearGradient(colors: [Color.gray.opacity(0.18), Color.gray.opacity(0.0)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(width: plot.width, height: aboveHeight)
                    .position(x: plot.midX, y: plot.minY + aboveHeight / 2)

                LinearGradient(colors: [Color.green.opacity(0.0), Color.green.opacity(0.18)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(width: plot.width, height: belowHeight)
                    .position(x: plot.midX, y: lineY + belowHeight / 2)
            }
        }
    }

    /// Whether a y-axis value is close enough to the budget value that their labels would collide.
    /// Used to hide the regular label there so the budget label takes priority.
    private func isNearBudget(_ amount: Double) -> Bool {
        guard let budgetPerBucket else { return false }
        return abs(amount - budgetPerBucket) < yMax * 0.08
    }

    /// Compact currency label for the y-axis (e.g. "$4K", "$1.2M") so large values never render
    /// in scientific notation ("4.0E6").
    private func abbreviatedAmount(_ value: Double) -> String {
        let absValue = abs(value)
        switch absValue {
        case 1_000_000...:
            return "$\((value / 1_000_000).formatted(.number.precision(.fractionLength(0...1))))M"
        case 1_000...:
            return "$\((value / 1_000).formatted(.number.precision(.fractionLength(0...1))))K"
        default:
            return "$\(value.formatted(.number.precision(.fractionLength(0))))"
        }
    }

    /// Dims segments outside the selected bucket.
    private func opacity(for bucketLabel: String) -> Double {
        guard let selected else { return 1 }
        return bucketLabel == selected ? 1 : 0.2
    }

    /// Total spent within a bucket (sum of its segments).
    private func bucketTotal(_ label: String) -> Double {
        segments.filter { $0.bucketLabel == label }.reduce(0) { $0 + $1.total }
    }

    /// Per-category amounts within a bucket, largest first (for the breakdown card).
    private func bucketBreakdown(_ label: String) -> [(category: String, total: Double)] {
        segments
            .filter { $0.bucketLabel == label && $0.total > 0 }
            .sorted { $0.total > $1.total }
            .map { ($0.category, $0.total) }
    }

    /// Floating card describing the selected bucket: the bucket total plus a per-category breakdown.
    private func infoCard(bucket: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(bucket)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(bucketTotal(bucket).asCurrency())
                    .font(.headline)
            }

            let breakdown = bucketBreakdown(bucket)
            if breakdown.isEmpty {
                Text("No spending")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(breakdown, id: \.category) { row in
                        HStack(spacing: 5) {
                            Circle()
                                .fill(CategoryStyle.color(for: row.category))
                                .frame(width: 7, height: 7)
                            Text(row.category)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(row.total.asCurrency())
                                .font(.caption2.weight(.medium))
                        }
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        )
    }
}

#Preview {
    TotalSpendingCard(
        total: 1679.44,
        previousTotal: 1707.49,
        segments: [
            CategorySegment(bucketLabel: "1-7", category: "Shopping", total: 200),
            CategorySegment(bucketLabel: "1-7", category: "Coffee", total: 60),
            CategorySegment(bucketLabel: "8-14", category: "Dining", total: 120),
            CategorySegment(bucketLabel: "15-21", category: "Shopping", total: 700),
            CategorySegment(bucketLabel: "15-21", category: "Transport", total: 200),
            CategorySegment(bucketLabel: "22-28", category: "Health", total: 80),
        ],
        bucketLabels: ["1-7", "8-14", "15-21", "22-28", "29-31"],
        projection: SpendingProjection(amount: 2100, periodNoun: "month", isWithinBudget: false, remaining: -420, daysRemaining: 12),
        budgetPerBucket: 400,
        mode: .constant(.total)
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
