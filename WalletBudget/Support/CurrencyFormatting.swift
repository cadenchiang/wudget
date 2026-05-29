import Foundation

extension Double {
    /// Formats the value as localized currency for display (e.g. `12.5` → "$12.50").
    ///
    /// Uses the device's currency when available, falling back to USD so the UI never
    /// shows a bare number.
    /// - Returns: A localized currency string.
    func asCurrency() -> String {
        let code = Locale.current.currency?.identifier ?? "USD"
        return self.formatted(.currency(code: code))
    }
}
