import AppIntents
import Foundation
import SwiftData

/// App Intent that imports one Apple Wallet transaction into the app.
///
/// This is the action WalletBudget publishes to the Shortcuts app: a "Transaction" personal
/// automation passes its Amount, Merchant, Currency, and Card to this action, which parses the
/// amount, builds an `Expense`, and saves it. Its parameters mirror the Wallet trigger's fields
/// so users can map them one-to-one. (Currency is accepted for parity but not yet stored; the
/// app uses the device's currency.)
struct WalletImportIntent: AppIntent {
    static var title: LocalizedStringResource = "Wallet Import"
    static var description = IntentDescription(
        "Imports an Apple Wallet transaction into WalletBudget. Map the Wallet automation's Amount, Merchant, and Card onto these fields."
    )

    /// Amount as delivered by the automation (often a currency-formatted string, e.g. "$6.22").
    @Parameter(title: "Amount") var amount: String

    /// Merchant/payee name (e.g. "Blue Bottle Coffee").
    @Parameter(title: "Merchant") var merchant: String

    /// Currency code/label from the transaction. Accepted for parity; not currently stored.
    @Parameter(title: "Currency", default: "") var currency: String

    /// Card/account name (e.g. "Apple Card").
    @Parameter(title: "Card", default: "") var card: String

    static var parameterSummary: some ParameterSummary {
        Summary("Import \(\.$amount) spent at \(\.$merchant)")
    }

    /// Validates inputs, builds an `Expense`, and persists it.
    /// - Returns: A short confirmation string (shown by Shortcuts/Siri).
    /// - Throws: `WalletImportError` when the amount is unparseable/zero, the merchant is empty,
    ///   or the save fails. Each failure is logged with its cause first.
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // Ensure categories are seeded/loaded so the import categorizes against the user's list.
        CategorySeeder.seedAndRefresh(context: SharedModelContainer.container.mainContext)

        guard let value = CurrencyParser.parse(amount), value != 0 else {
            Log.intent.error("Rejected import: unparseable/zero amount \(amount, privacy: .public)")
            throw WalletImportError.invalidAmount(amount)
        }

        let cleanMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanMerchant.isEmpty else {
            Log.intent.error("Rejected import: empty merchant (amount \(value))")
            throw WalletImportError.missingMerchant
        }

        let expense = Expense(amount: value, merchant: cleanMerchant, card: card)
        let context = SharedModelContainer.container.mainContext
        context.insert(expense)
        do {
            try context.save()
        } catch {
            Log.intent.error("Failed to save imported transaction at \(cleanMerchant, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw WalletImportError.saveFailed
        }

        // Record that the Wallet automation has successfully reached the app at least once.
        // The onboarding's final screen observes this to confirm the sync works.
        UserDefaults.standard.set(true, forKey: WalletImportIntent.receivedKey)

        Log.intent.info("Imported \(expense.amount) at \(cleanMerchant, privacy: .public) [\(expense.category, privacy: .public)] currency=\(currency, privacy: .public)")
        return .result(value: "Imported \(cleanMerchant) in \(expense.category)")
    }

    /// `UserDefaults` key set once the first Wallet Import succeeds (used by onboarding's sync check).
    static let receivedKey = "walletImportReceived"
}

/// Errors surfaced to Shortcuts/Siri when a `WalletImportIntent` cannot complete.
enum WalletImportError: Error, CustomLocalizedStringResourceConvertible {
    /// The amount string could not be parsed into a non-zero number. Carries the raw input.
    case invalidAmount(String)
    /// No merchant name was provided.
    case missingMerchant
    /// SwiftData failed to persist the expense.
    case saveFailed

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidAmount(let raw): return "Couldn't read the amount \"\(raw)\"."
        case .missingMerchant: return "The transaction had no merchant name."
        case .saveFailed: return "Couldn't save the transaction. Please try again."
        }
    }
}
