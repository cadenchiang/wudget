import WidgetKit
import SwiftUI

/// Timeline entry carrying the latest spending snapshot.
struct SpendingEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// Provides entries from the App Group snapshot the app writes.
struct SpendingProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpendingEntry {
        SpendingEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (SpendingEntry) -> Void) {
        completion(SpendingEntry(date: Date(), snapshot: WidgetStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpendingEntry>) -> Void) {
        let entry = SpendingEntry(date: Date(), snapshot: WidgetStore.load())
        // The app reloads on changes; refresh hourly as a fallback.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

/// A home-screen widget showing this month's spending and budget.
struct SpendingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SpendingWidget", provider: SpendingProvider()) { entry in
            SpendingWidgetView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Spending")
        .description("This month's spending and budget.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// Renders the small and medium widget layouts.
struct SpendingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WidgetSnapshot

    var body: some View {
        switch family {
        case .systemMedium: medium
        default: small
        }
    }

    /// The spending amount, colored red when over budget.
    private var amountColor: Color { snapshot.isOverBudget ? .red : .primary }

    /// A short budget status line.
    private var statusLine: some View {
        Group {
            if snapshot.hasBudget {
                if snapshot.remaining >= 0 {
                    Text("\(snapshot.money(snapshot.remaining)) left")
                        .foregroundStyle(.green)
                } else {
                    Text("\(snapshot.money(-snapshot.remaining)) over")
                        .foregroundStyle(.red)
                }
            } else {
                Text("No budget set").foregroundStyle(.secondary)
            }
        }
        .font(.caption.weight(.medium))
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Spent", systemImage: "wallet.bifold")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(snapshot.money(snapshot.monthSpent))
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(amountColor)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(snapshot.periodLabel.isEmpty ? "This month" : snapshot.periodLabel)
                .font(.caption2).foregroundStyle(.secondary)
            statusLine
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.periodLabel.isEmpty ? "This month" : snapshot.periodLabel)
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(snapshot.money(snapshot.monthSpent))
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(amountColor)
                    .minimumScaleFactor(0.6).lineLimit(1)
                statusLine
                Spacer(minLength: 0)
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("Recent").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                if snapshot.recent.isEmpty {
                    Text("No transactions").font(.caption2).foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.recent) { txn in
                        HStack {
                            Text(txn.merchant).font(.caption2).lineLimit(1)
                            Spacer(minLength: 4)
                            Text(snapshot.money(txn.amount)).font(.caption2.weight(.medium))
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
