import Foundation
import SwiftData

/// A single spending transaction tracked by the app, persisted with SwiftData.
///
/// Expenses arrive either from the Wallet Shortcut (via `AddTransactionIntent`) or
/// from manual entry in the UI. `category` is derived from `merchant` at creation
/// time using `ExpenseCategorizer`.
///
/// The type is named `Expense` (not `Transaction`) to avoid colliding with
/// `SwiftUI.Transaction`, which would make the symbol ambiguous in view files.
@Model
final class Expense {
    /// Stable unique identifier used by SwiftData and for de-duplication.
    @Attribute(.unique) var id: UUID

    /// Spend amount in the user's currency. Always stored as a positive number.
    var amount: Double

    /// Human-readable merchant name (e.g. "Blue Bottle Coffee").
    var merchant: String

    /// Name of the card/account used (e.g. "Apple Card"). Empty when unknown.
    var card: String

    /// When the purchase occurred.
    var date: Date

    /// Derived spending category (see `ExpenseCategorizer`).
    var category: String

    /// Free-form note attached to the purchase (editable later).
    var notes: String = ""

    /// When true, this is treated as a fixed cost and excluded from Variable Spending / the budget.
    var excludedFromBudget: Bool = false

    /// True when this came from an Apple Pay / Wallet Import (vs. manual entry). Only these show
    /// the location map.
    var viaWalletImport: Bool = false

    /// Captured location of the purchase (nil when unknown/not permitted).
    var latitude: Double?
    var longitude: Double?
    /// Reverse-geocoded place/city name for the location (empty when unknown).
    var locationName: String = ""

    /// Recurrence stored as `RecurrenceFrequency.rawValue`. `"none"` means one-time.
    /// Stored (not the enum) so it can be used in SwiftData `#Predicate` queries.
    var recurrenceRaw: String = RecurrenceFrequency.none.rawValue

    /// Typed accessor for `recurrenceRaw`.
    var recurrence: RecurrenceFrequency {
        get { RecurrenceFrequency(rawValue: recurrenceRaw) ?? .none }
        set { recurrenceRaw = newValue.rawValue }
    }

    /// Convenience flag: whether this repeats at all. Not persisted; query on `recurrenceRaw`.
    var isRecurring: Bool { recurrence != .none }

    /// Creates an expense.
    /// - Parameters:
    ///   - id: Unique id. Defaults to a fresh `UUID`.
    ///   - amount: Spend amount; the absolute value is stored (refunds collapse to spend).
    ///   - merchant: Merchant name; trimmed of surrounding whitespace.
    ///   - card: Card/account name; trimmed. Empty string when unknown.
    ///   - date: Purchase date. Defaults to now.
    ///   - category: Optional explicit category. When `nil`, it is derived from `merchant`.
    ///   - recurrence: How often it repeats. Defaults to `.none` (one-time).
    /// - Note: An empty `merchant` yields the "Other" category and is allowed at the
    ///   model layer; callers (intent/UI) are responsible for rejecting empty merchants.
    init(
        id: UUID = UUID(),
        amount: Double,
        merchant: String,
        card: String = "",
        date: Date = Date(),
        category: String? = nil,
        recurrence: RecurrenceFrequency = .none,
        notes: String = ""
    ) {
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = id
        self.amount = abs(amount)
        self.merchant = trimmedMerchant
        self.card = card.trimmingCharacters(in: .whitespacesAndNewlines)
        self.date = date
        self.category = category ?? ExpenseCategorizer.category(for: trimmedMerchant)
        self.recurrenceRaw = recurrence.rawValue
        self.notes = notes
    }
}
