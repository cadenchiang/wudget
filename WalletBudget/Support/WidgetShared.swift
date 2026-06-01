import Foundation

/// App Group shared by the app and the widget extension. (Registered on the developer portal for
/// device/App Store builds; works in the Simulator without registration.)
let widgetAppGroup = "group.com.cadenchiang.walletbudget"

/// A single recent transaction shown in the widget.
struct WidgetTxn: Codable, Identifiable {
    var id = UUID()
    let merchant: String
    let amount: Double
    let category: String
}

/// A compact spending summary the app writes for the widget to display.
struct WidgetSnapshot: Codable {
    let monthSpent: Double
    let monthBudget: Double      // 0 when no budget is set
    let periodLabel: String      // e.g. "May"
    let currencyCode: String
    let recent: [WidgetTxn]

    var remaining: Double { monthBudget - monthSpent }
    var hasBudget: Bool { monthBudget > 0 }
    var isOverBudget: Bool { hasBudget && monthSpent > monthBudget }

    /// Percent of the month's budget spent so far (0 when no budget). Can exceed 100 when over.
    var percentUsed: Int {
        guard hasBudget else { return 0 }
        return Int((monthSpent / monthBudget * 100).rounded())
    }

    /// Formats an amount in the snapshot's currency (whole dollars for compactness).
    func money(_ value: Double) -> String {
        value.formatted(.currency(code: currencyCode).precision(.fractionLength(0)))
    }

    static let empty = WidgetSnapshot(monthSpent: 0, monthBudget: 0, periodLabel: "", currencyCode: "USD", recent: [])
}

/// Reads and writes the widget snapshot in the shared App Group's `UserDefaults`.
enum WidgetStore {
    private static let key = "widget.snapshot"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: widgetAppGroup) }

    /// Persists the snapshot for the widget to read.
    static func save(_ snapshot: WidgetSnapshot) {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    /// Loads the latest snapshot, or `.empty` when none has been written.
    static func load() -> WidgetSnapshot {
        guard let defaults, let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else { return .empty }
        return snapshot
    }
}
