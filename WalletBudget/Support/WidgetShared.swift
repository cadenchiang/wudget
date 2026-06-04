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
    /// Spending excluding fixed costs ("Everyday Spending"). Optional so snapshots written by
    /// older app versions (without this key) still decode; `spent(variableOnly:)` falls back
    /// to `monthSpent` until the app writes a fresh snapshot.
    let monthVariableSpent: Double?
    let monthBudget: Double      // 0 when no budget is set
    let periodLabel: String      // e.g. "May"
    let currencyCode: String
    let recent: [WidgetTxn]

    var hasBudget: Bool { monthBudget > 0 }

    /// The spent amount for the widget's chosen scope: everything, or only variable
    /// (non-fixed) costs. Falls back to the total when the snapshot predates the field.
    func spent(variableOnly: Bool) -> Double {
        variableOnly ? (monthVariableSpent ?? monthSpent) : monthSpent
    }

    /// Budget left after the given spent amount (negative when over budget).
    func remaining(spent: Double) -> Double { monthBudget - spent }

    /// Whether the given spent amount exceeds the budget (false when no budget is set).
    func isOverBudget(spent: Double) -> Bool { hasBudget && spent > monthBudget }

    /// Percent of the month's budget used by the given spent amount (0 when no budget).
    /// Can exceed 100 when over.
    func percentUsed(spent: Double) -> Int {
        guard hasBudget else { return 0 }
        return Int((spent / monthBudget * 100).rounded())
    }

    /// Formats an amount in the snapshot's currency (whole dollars for compactness).
    func money(_ value: Double) -> String {
        value.formatted(.currency(code: currencyCode).precision(.fractionLength(0)))
    }

    static let empty = WidgetSnapshot(monthSpent: 0, monthVariableSpent: 0, monthBudget: 0, periodLabel: "", currencyCode: "USD", recent: [])
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
