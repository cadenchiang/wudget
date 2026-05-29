import UIKit

/// Centralized haptic feedback, gated by the user's "Haptic Feedback" setting.
///
/// Reads `UserDefaults` key `haptics.enabled` (default on) so it can be called from anywhere,
/// including non-SwiftUI contexts, without an environment dependency.
enum Haptics {
    /// Key shared with the Settings toggle (`@AppStorage`).
    static let enabledKey = "haptics.enabled"

    /// Whether haptics are enabled (defaults to `true` when unset).
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    /// A physical tap (button presses, selections).
    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    /// A light selection tick (pickers, scrubbing).
    static func selection() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// A success notification (saves, completion).
    static func success() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
