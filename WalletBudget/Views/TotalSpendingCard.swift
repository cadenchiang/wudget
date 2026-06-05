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

    /// A one-sentence budget summary: how much is left to spend this period (and over how many
    /// days), or how much over budget; `nil` when no budget is set. The dollar amount is colored
    /// green (under) or red (over); the rest of the sentence stays primary.
    var budgetSentence: Text? {
        guard let remaining else { return nil }
        // Tail framing per span: "today" reads naturally for a day; a year shows a per-month pace
        // (a big yearly remainder with "days left" isn't actionable); other spans use days-left.
        let tail: Text = {
            switch periodNoun {
            case "day":
                return Text(" today.").foregroundStyle(.primary)
            case "year":
                if remaining > 0 {
                    let monthsLeft = max(1, Int((Double(daysRemaining) / 30.4).rounded()))
                    let perMonth = remaining / Double(monthsLeft)
                    return Text(" this year, about \(perMonth.asCurrency()) a month.").foregroundStyle(.primary)
                }
                return Text(" this year.").foregroundStyle(.primary)
            default:
                let dayWord = daysRemaining == 1 ? "day" : "days"
                return Text(" with \(daysRemaining) \(dayWord) left this \(periodNoun).").foregroundStyle(.primary)
            }
        }()
        if remaining >= 0.005 {
            return Text("You have ").foregroundStyle(.primary)
                + Text(remaining.asCurrency()).foregroundStyle(.green).fontWeight(.semibold)
                + Text(" left to spend").foregroundStyle(.primary)
                + tail
        } else if remaining <= -0.005 {
            return Text("You're ").foregroundStyle(.primary)
                + Text(abs(remaining).asCurrency()).foregroundStyle(.red).fontWeight(.semibold)
                + Text(" over budget").foregroundStyle(.primary)
                + tail
        } else {
            // Spent right at the budget (within a cent).
            return Text("You've hit your budget").foregroundStyle(.primary) + tail
        }
    }
}

/// Whether the spending card counts everything or only variable (non-fixed) costs.
enum SpendingMode: String, CaseIterable, Identifiable {
    case total
    case variable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .total: return "Total Spending"
        case .variable: return "Everyday Spending"
        }
    }
}

/// The spending hero: the period total and a Robinhood-style cumulative line graph over the
/// period's time buckets. Dragging across the chart scrubs a hairline + dot along the line and
/// raises a breakdown card for that bucket; tapping empty space clears the selection.
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
    /// Period noun (day/week/month/year), used for the fallback blurb so the line is never blank.
    var periodNoun: String = "period"

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

    /// Upper bound for the y-axis: the cumulative total or the full budget pace, whichever is
    /// larger, with headroom. Falls back to a fixed value when both are zero so the axis renders.
    private var yMax: Double {
        let cumulativeMax = cumulativePoints.last?.total ?? 0
        let budgetEnd = (budgetPerBucket ?? 0) * Double(bucketLabels.count)
        let ceiling = max(cumulativeMax, budgetEnd)
        return ceiling > 0 ? ceiling * 1.1 : 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(total.asCurrency())
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if hasComparison {
                    Image(systemName: delta <= 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .foregroundStyle(delta <= 0 ? .green : .red)
                        .font(.title3)
                }
            }


            chart
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Cumulative points for the line: running total of spending at the end of each bucket.
    private var cumulativePoints: [(label: String, total: Double)] {
        var running = 0.0
        return bucketLabels.map { label in
            running += bucketTotal(label)
            return (label, running)
        }
    }

    /// Robinhood-style line graph: cumulative spending across the period, scrubbed by dragging
    /// (a hairline + dot track the finger while the breakdown card describes that bucket), with
    /// a dashed budget pace line when a budget is set.
    private var chart: some View {
        Chart {
            ForEach(cumulativePoints, id: \.label) { point in
                LineMark(
                    x: .value("Period", point.label),
                    y: .value("Spent", point.total),
                    series: .value("Series", "spent")
                )
                .foregroundStyle(.primary)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            if let budgetPerBucket {
                ForEach(Array(bucketLabels.enumerated()), id: \.element) { index, label in
                    LineMark(
                        x: .value("Period", label),
                        y: .value("Budget", budgetPerBucket * Double(index + 1)),
                        series: .value("Series", "budget")
                    )
                    .foregroundStyle(budgetColor.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [2, 4]))
                }
            }
            if let selected, let point = cumulativePoints.first(where: { $0.label == selected }) {
                RuleMark(x: .value("Period", selected))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                PointMark(
                    x: .value("Period", point.label),
                    y: .value("Spent", point.total)
                )
                .foregroundStyle(.primary)
                .symbolSize(70)
            }
        }
        .chartXScale(domain: bucketLabels)
        .chartYScale(domain: 0...yMax)
        .chartXSelection(value: $selected)
        .chartLegend(.hidden)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 260)
        .padding(.top, 8)
        // Bleed past the page gutter so the line runs edge to edge, Robinhood-style.
        .padding(.horizontal, -20)
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
                    let scrubX = plot.minX + xPosition
                    // Place the card beside the scrub line (right when on the left half, else
                    // left) so it never covers the tracked point.
                    let preferRight = scrubX < plot.midX
                    let sideX = preferRight ? scrubX + gap + cardWidth / 2 : scrubX - gap - cardWidth / 2
                    let clampedX = min(max(sideX, plot.minX + cardWidth / 2), plot.maxX - cardWidth / 2)
                    infoCard(bucket: selected)
                        .frame(width: cardWidth)
                        .position(x: clampedX, y: plot.minY + 30)
                }
            }
        }
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
        budgetPerBucket: 400
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
