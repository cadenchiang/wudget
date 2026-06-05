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

/// One transaction's contribution to the spending line: its exact timestamp, amount, and category.
struct SpendingChartEntry {
    let date: Date
    let amount: Double
    let category: String
}

/// The spending hero: the period total over a Robinhood-style cumulative line built from the
/// exact timestamps of every transaction. The line stops at "now" with a live dot (the future
/// stays blank); dragging scrubs a hairline with a pulsing dot along the line and raises a
/// breakdown card for that moment. A dotted horizontal line marks the period budget.
struct TotalSpendingCard: View {
    /// Total spent in the current period.
    let total: Double
    /// Total spent in the previous period (for the comparison arrow).
    let previousTotal: Double
    /// The period's transactions (any order; the card sorts by time).
    let entries: [SpendingChartEntry]
    /// The period's full date range — the x-axis domain, so unelapsed time stays blank.
    let domain: ClosedRange<Date>
    /// Optional forward-looking projection (used by the blurb card outside this view).
    let projection: SpendingProjection?
    /// Optional total budget for the period; drawn as a dotted horizontal line.
    let periodBudget: Double?

    /// The raw drag position from the chart (continuous).
    @State private var selectedDate: Date?
    /// The drag position snapped to the nearest logged transaction.
    @State private var snappedDate: Date?

    private var delta: Double { total - previousTotal }

    /// Whether there's previous-period spending to compare against.
    private var hasComparison: Bool { previousTotal > 0 }

    /// Where the line ends: now, clamped into the domain (a period fully in the past ends at its
    /// own end).
    private var lineEnd: Date { min(Date(), domain.upperBound) }

    /// The cumulative line: starts at zero, steps up at each transaction, and runs flat to now.
    private var linePoints: [(date: Date, total: Double)] {
        Self.cumulativeLine(entries: entries, from: domain.lowerBound, to: lineEnd)
    }

    /// Builds the cumulative line for `entries` between `start` and `end`: a zero anchor at
    /// `start`, a point at each transaction's exact timestamp (entries after `end` are ignored,
    /// earlier ones clamp to `start`), and a final point at `end` so the line runs flat to "now".
    static func cumulativeLine(entries: [SpendingChartEntry], from start: Date, to end: Date) -> [(date: Date, total: Double)] {
        let sorted = entries
            .filter { $0.date <= end }
            .sorted { $0.date < $1.date }
        var points: [(date: Date, total: Double)] = [(start, 0)]
        var running = 0.0
        for entry in sorted {
            running += entry.amount
            points.append((max(entry.date, start), running))
        }
        if let last = points.last, last.date < end {
            points.append((end, running))
        }
        return points
    }

    /// Cumulative total at the scrubbed moment (the last line point at or before it).
    private func cumulativeTotal(at date: Date) -> Double {
        linePoints.last(where: { $0.date <= date })?.total ?? 0
    }

    /// Per-category totals up to the scrubbed moment, largest first (top three).
    private func breakdown(at date: Date) -> [(category: String, total: Double)] {
        var totals: [String: Double] = [:]
        for entry in entries where entry.date <= date {
            totals[entry.category, default: 0] += entry.amount
        }
        return totals.sorted { $0.value > $1.value }.prefix(3).map { ($0.key, $0.value) }
    }

    /// The line/dot color: green while under budget, red when over; monochrome with no budget.
    private var lineColor: Color {
        guard let periodBudget else { return .primary }
        return (linePoints.last?.total ?? 0) <= periodBudget ? .green : .red
    }

    /// Transaction timestamps inside the drawn line — the snap targets for scrubbing.
    private var snapDates: [Date] {
        entries.map(\.date).filter { $0 >= domain.lowerBound && $0 <= lineEnd }.sorted()
    }

    /// The logged moment nearest to a raw scrub position.
    private func snap(_ date: Date) -> Date? {
        snapDates.min(by: { abs($0.timeIntervalSince(date)) < abs($1.timeIntervalSince(date)) })
    }

    /// Upper y-bound: the spent total or the budget, whichever is larger, with headroom.
    private var yMax: Double {
        let ceiling = max(linePoints.last?.total ?? 0, periodBudget ?? 0)
        return ceiling > 0 ? ceiling * 1.15 : 100
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

    /// The bare, edge-to-edge market-style chart.
    private var chart: some View {
        Chart {
            ForEach(Array(linePoints.enumerated()), id: \.offset) { _, point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Spent", point.total)
                )
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            // The budget: one dotted horizontal line straight across.
            if let periodBudget {
                RuleMark(y: .value("Budget", periodBudget))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [1, 4]))
            }
            if let snappedDate {
                RuleMark(x: .value("Time", snappedDate))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
        }
        .chartXScale(domain: domain.lowerBound...domain.upperBound)
        .chartYScale(domain: 0...yMax)
        .chartXSelection(value: $selectedDate)
        .chartLegend(.hidden)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 260)
        .padding(.top, 8)
        // Bleed past the page gutter so the line runs edge to edge, Robinhood-style.
        .padding(.horizontal, -20)
        // Snap the scrub to the nearest logged transaction and tick once per point.
        .onChange(of: selectedDate) { _, newValue in
            guard let newValue else {
                snappedDate = nil
                return
            }
            let snapped = snap(newValue)
            if snapped != snappedDate {
                snappedDate = snapped
                Haptics.selection()
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                if let plotAnchor = proxy.plotFrame {
                    let plot = geo[plotAnchor]
                    // Live dot at the end of the line.
                    if let endX = proxy.position(forX: lineEnd),
                       let endY = proxy.position(forY: linePoints.last?.total ?? 0) {
                        Circle()
                            .fill(lineColor)
                            .frame(width: 9, height: 9)
                            .position(x: plot.minX + endX, y: plot.minY + endY)
                    }
                    // Pulsing dot + breakdown card at the snapped transaction.
                    if let snappedDate,
                       let scrubX = proxy.position(forX: snappedDate),
                       let scrubY = proxy.position(forY: cumulativeTotal(at: snappedDate)) {
                        pulsingDot
                            .position(x: plot.minX + scrubX, y: plot.minY + scrubY)
                        let cardWidth: CGFloat = 150
                        let gap: CGFloat = 18
                        let x = plot.minX + scrubX
                        let preferRight = x < plot.midX
                        let sideX = preferRight ? x + gap + cardWidth / 2 : x - gap - cardWidth / 2
                        let clampedX = min(max(sideX, plot.minX + cardWidth / 2), plot.maxX - cardWidth / 2)
                        infoCard(at: snappedDate)
                            .frame(width: cardWidth)
                            .position(x: clampedX, y: plot.minY + 34)
                    }
                }
            }
        }
    }

    /// The scrub indicator: a solid dot inside a halo that softly pulses while the finger is down.
    private var pulsingDot: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                Circle()
                    .fill(lineColor.opacity(0.18))
                    .frame(width: 26, height: 26)
                    .scaleEffect(1 + 0.18 * sin(t * 4))
                Circle()
                    .fill(lineColor)
                    .frame(width: 10, height: 10)
            }
        }
    }

    /// Floating card describing the scrubbed moment: timestamp, spent-so-far, top categories.
    private func infoCard(at date: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(date.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(cumulativeTotal(at: date).asCurrency())
                    .font(.headline)
            }

            let rows = breakdown(at: date)
            if rows.isEmpty {
                Text("No spending yet")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(rows, id: \.category) { row in
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
    let now = Date()
    return TotalSpendingCard(
        total: 1240,
        previousTotal: 1407.49,
        entries: [
            SpendingChartEntry(date: now.addingTimeInterval(-86400 * 20), amount: 260, category: "Shopping"),
            SpendingChartEntry(date: now.addingTimeInterval(-86400 * 16), amount: 60, category: "Coffee"),
            SpendingChartEntry(date: now.addingTimeInterval(-86400 * 12), amount: 420, category: "Dining"),
            SpendingChartEntry(date: now.addingTimeInterval(-86400 * 6), amount: 200, category: "Transport"),
            SpendingChartEntry(date: now.addingTimeInterval(-86400 * 2), amount: 300, category: "Shopping"),
        ],
        domain: now.addingTimeInterval(-86400 * 25)...now.addingTimeInterval(86400 * 5),
        projection: nil,
        periodBudget: 1600
    )
    .padding(20)
}
