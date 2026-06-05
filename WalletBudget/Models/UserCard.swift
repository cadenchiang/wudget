import Foundation
import SwiftData
import SwiftUI

/// A card the user actually owns: listed in My Cards, offered by the add-transaction card step,
/// and tracked for credit utilization against its limit.
@Model
final class UserCard {
    /// Stable identifier used for cloud sync (not unique-constrained so legacy rows
    /// migrate safely; the sync layer treats it as the primary key).
    var id: UUID = UUID()
    /// Canonical display name (matches `CardLibrary` naming when the card is a known brand).
    var name: String = ""
    /// Optional credit limit; utilization is month spend / limit. `nil` hides the utilization bar.
    var creditLimit: Double?
    /// Creation time, used as a stable tiebreaker for cards with no spending yet.
    var createdAt: Date = Date()
    /// Last local modification time; drives last-write-wins cloud sync merges.
    var updatedAt: Date = Date()

    /// Creates a card.
    /// - Parameters:
    ///   - name: Canonical card name.
    ///   - creditLimit: Optional limit for utilization tracking.
    init(name: String, creditLimit: Double? = nil) {
        self.id = UUID()
        self.name = name
        self.creditLimit = creditLimit
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

/// Credit-utilization math and scoring tiers.
///
/// Thresholds follow standard credit-score guidance: keeping utilization under 30% of the limit
/// is considered healthy (under 10% ideal), 30-50% starts to weigh on scores, and above 50%
/// actively hurts.
enum CardUtilization {
    /// Utilization as a 0+ fraction (0.31 = 31%), or `nil` when there's no positive limit.
    /// - Parameters:
    ///   - spent: Amount charged in the period.
    ///   - limit: The card's credit limit.
    static func fraction(spent: Double, limit: Double?) -> Double? {
        guard let limit, limit > 0 else { return nil }
        return max(0, spent / limit)
    }

    /// The health tier for a utilization fraction.
    enum Tier {
        case good     // ≤ 30%
        case warning  // 30-50%
        case high     // > 50%

        var color: Color {
            switch self {
            case .good: return .green
            case .warning: return .orange
            case .high: return .red
            }
        }
    }

    /// Tier for a utilization fraction (0.30 boundary counts as good).
    static func tier(for fraction: Double) -> Tier {
        if fraction <= 0.30 { return .good }
        if fraction <= 0.50 { return .warning }
        return .high
    }
}
