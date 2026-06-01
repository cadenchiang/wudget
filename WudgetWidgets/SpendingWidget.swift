import WidgetKit
import SwiftUI

/// Timeline entry carrying the latest spending snapshot and the user's chosen display mode.
struct SpendingEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let displayMode: WidgetDisplayMode
}

/// Provides entries from the App Group snapshot the app writes, honoring the widget's
/// user-selected configuration (dollar amount vs percent of budget).
struct SpendingProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SpendingEntry {
        SpendingEntry(date: Date(), snapshot: .empty, displayMode: .amount)
    }

    func snapshot(for configuration: SpendingWidgetConfig, in context: Context) async -> SpendingEntry {
        SpendingEntry(date: Date(), snapshot: WidgetStore.load(), displayMode: configuration.displayMode)
    }

    func timeline(for configuration: SpendingWidgetConfig, in context: Context) async -> Timeline<SpendingEntry> {
        let entry = SpendingEntry(date: Date(), snapshot: WidgetStore.load(), displayMode: configuration.displayMode)
        // The app reloads on changes; refresh hourly as a fallback.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        return Timeline(entries: [entry], policy: .after(next))
    }
}

/// A home-screen widget showing this month's spending and budget. Configurable: long-press →
/// Edit Widget to switch the big number between a dollar amount and a percent of budget.
struct SpendingWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "SpendingWidget", intent: SpendingWidgetConfig.self, provider: SpendingProvider()) { entry in
            SpendingWidgetView(snapshot: entry.snapshot, displayMode: entry.displayMode)
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
    /// Whether the big number is a dollar amount or a percent of budget.
    var displayMode: WidgetDisplayMode = .amount

    var body: some View {
        switch family {
        case .systemMedium: medium
        default: small
        }
    }

    /// The big number: a percent of budget when the user chose that mode and a budget exists,
    /// otherwise the dollar amount (the natural fallback when there's nothing to take a percent of).
    private var primaryText: String {
        if displayMode == .percent && snapshot.hasBudget {
            return "\(snapshot.percentUsed)%"
        }
        return snapshot.money(snapshot.monthSpent)
    }

    /// The spending value, colored red when over budget.
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
            Text(primaryText)
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
                Text(primaryText)
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
