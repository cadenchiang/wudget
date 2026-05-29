import Foundation

extension Double {
    /// Formats the value as localized currency for display (e.g. `12.5` → "$12.50").
    ///
    /// Uses the currency the user chose during onboarding (stored under
    /// `ProfileKeys.currencyCode`) when present, otherwise the device's currency, falling back to
    /// USD so the UI never shows a bare number.
    /// - Returns: A localized currency string.
    func asCurrency() -> String {
        self.formatted(.currency(code: Self.activeCurrencyCode))
    }

    /// Like `asCurrency()` but without cents (e.g. `500` → "$500"), for compact chips/labels.
    /// - Returns: A localized whole-dollar currency string.
    func asCurrencyRounded() -> String {
        self.formatted(.currency(code: Self.activeCurrencyCode).precision(.fractionLength(0)))
    }

    /// The currency code to format with: the onboarding choice, else device, else USD.
    private static var activeCurrencyCode: String {
        let stored = UserDefaults.standard.string(forKey: ProfileKeys.currencyCode)
        return (stored?.isEmpty == false ? stored : nil)
            ?? Locale.current.currency?.identifier
            ?? "USD"
    }
}
