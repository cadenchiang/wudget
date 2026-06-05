import Foundation
import os

/// Centralized structured logging for the app.
///
/// Each category maps to one subsystem area so logs can be filtered in Console.app.
/// Using `os.Logger` keeps logging lightweight and native (no extra dependencies).
enum Log {
    /// Subsystem identifier shared by every logger.
    private static let subsystem = "com.cadenchiang.walletbudget"

    /// Logs related to transaction persistence (load/save/decode failures).
    static let store = Logger(subsystem: subsystem, category: "store")

    /// Logs emitted while handling the Wallet App Intent.
    static let intent = Logger(subsystem: subsystem, category: "intent")

    /// Logs related to amount parsing and categorization.
    static let parsing = Logger(subsystem: subsystem, category: "parsing")

    /// Logs related to UI-facing stores and budget math.
    static let ui = Logger(subsystem: subsystem, category: "ui")

    /// Logs related to capturing device location for transaction tagging.
    static let location = Logger(subsystem: subsystem, category: "location")

    /// Logs related to authentication (sign-in, sign-up, session restore, sign-out).
    static let auth = Logger(subsystem: subsystem, category: "auth")

    /// Logs related to cloud sync (pull/merge/push cycles, tombstones).
    static let sync = Logger(subsystem: subsystem, category: "sync")
}
