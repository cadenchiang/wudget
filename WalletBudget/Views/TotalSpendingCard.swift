import SwiftUI
import Charts

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

    @State private var selected: String?

    private var delta: Double { total - previousTotal }

    /// Whether there's previous-period spending to compare against.
    private var hasComparison: Bool { previousTotal > 0 }

    /// One-line comparison versus the previous period (only meaningful when `hasComparison`).
    private var comparison: String {
        let direction = delta <= 0 ? "less" : "more"
        return "So far, you've spent \(abs(delta).asCurrency()) \(direction) than last period at this time."
    }

    /// Upper bound for the y-axis. Falls back to a fixed value when there's no spending so the
    /// axis (and its baseline above the dates) still renders; otherwise adds a little headroom.
    private var yMax: Double {
        let maxBucket = bucketLabels.map(bucketTotal).max() ?? 0
        return maxBucket > 0 ? maxBucket * 1.1 : 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Total Spending")
                .font(.subheadline)
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                Text(total.asCurrency())
                    .font(.system(size: 30, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if hasComparison {
                    Image(systemName: delta <= 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .foregroundStyle(delta <= 0 ? .green : .red)
                        .font(.title3)
                }
            }

            if hasComparison {
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

    /// Stacked, category-colored bars over the time buckets, with tap selection.
    private var chart: some View {
        Chart(segments) { segment in
            BarMark(
                x: .value("Period", segment.bucketLabel),
                y: .value("Spent", segment.total)
            )
            .foregroundStyle(CategoryStyle.color(for: segment.category))
            .opacity(opacity(for: segment.bucketLabel))
            .cornerRadius(3)
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
            AxisMarks(position: .trailing) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .frame(height: 190)
        .padding(.top, 4)
        .animation(.easeInOut(duration: 0.2), value: selected)
        .chartOverlay { proxy in
            GeometryReader { geo in
                if let selected,
                   let plotAnchor = proxy.plotFrame,
                   let xPosition = proxy.position(forX: selected) {
                    let plot = geo[plotAnchor]
                    let cardHalfWidth: CGFloat = 70
                    let clampedX = min(max(plot.minX + xPosition, plot.minX + cardHalfWidth), plot.maxX - cardHalfWidth)
                    infoCard(bucket: selected)
                        .frame(width: cardHalfWidth * 2)
                        .position(x: clampedX, y: plot.minY + 34)
                }
            }
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

    /// Floating card describing the selected bucket.
    private func infoCard(bucket: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(bucket)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(bucketTotal(bucket).asCurrency())
                .font(.headline)
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
        bucketLabels: ["1-7", "8-14", "15-21", "22-28", "29-31"]
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
