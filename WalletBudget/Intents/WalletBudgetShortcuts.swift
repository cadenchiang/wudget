import AppIntents

/// Registers the app's intents with the Shortcuts app and Siri so they are discoverable
/// without the user wiring anything up manually.
///
/// The exposed "Wallet Import" action is what a Wallet "Transaction" automation calls.
struct WalletBudgetShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WalletImportIntent(),
            phrases: [
                "Import a transaction into \(.applicationName)",
                "Wallet import in \(.applicationName)"
            ],
            shortTitle: "Automatically Log Card Payment",
            systemImageName: "creditcard"
        )
    }
}
