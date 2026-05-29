import LocalAuthentication

/// Biometric / passcode app-lock helper, gated by the "Require Face ID" setting.
enum AppLock {
    /// `UserDefaults`/`@AppStorage` key for whether the lock is enabled.
    static let enabledKey = "lock.enabled"

    /// Whether the app lock is turned on.
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    /// Prompts Face ID / Touch ID, falling back to the device passcode.
    ///
    /// If no biometrics or passcode are available the user is *not* locked out, `completion(true)`
    /// is returned so the app stays usable.
    /// - Parameter completion: Called on the main thread with whether authentication succeeded.
    static func authenticate(reason: String = "Unlock WalletBudget", completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            completion(true)
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
            DispatchQueue.main.async { completion(success) }
        }
    }
}
