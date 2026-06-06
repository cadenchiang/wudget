import Foundation
import SwiftData

/// Seeds the default categories on first launch and keeps `CategoryRegistry` in sync.
enum CategorySeeder {
    /// Inserts the default categories if none exist, then refreshes the in-memory registry.
    /// Safe to call repeatedly (it no-ops when categories already exist).
    /// - Parameter context: The model context to seed/read (the same one views query).
    @MainActor
    static func seedAndRefresh(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<SpendingCategory>())) ?? []
        var nextOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
        var changed = false

        // One-time palette fix (2026-06): Rent moved teal→gray, School teal→indigo.
        // Only recolors categories still wearing the old default, so any color the
        // user picked themselves is preserved.
        let paletteFixes: [String: (old: String, new: String)] = [
            "Rent": ("teal", "gray"),
            "School": ("teal", "indigo"),
        ]
        for category in existing {
            if let fix = paletteFixes[category.seedKey ?? ""], category.colorName == fix.old {
                category.colorName = fix.new
                changed = true
            }
        }

        for def in CategoryCatalog.defaults {
            // Already seeded (even if the user renamed it) — leave it alone.
            if existing.contains(where: { $0.seedKey == def.name }) { continue }

            // Pre-existing default from before seedKey existed — backfill its identity.
            if let legacy = existing.first(where: { $0.seedKey == nil && $0.name.caseInsensitiveCompare(def.name) == .orderedSame }) {
                legacy.seedKey = def.name
                changed = true
                continue
            }

            // New default (fresh install or a newly added one) — insert it.
            let order = existing.isEmpty ? (CategoryCatalog.defaults.firstIndex { $0.name == def.name } ?? nextOrder) : nextOrder
            context.insert(SpendingCategory(
                name: def.name,
                colorName: def.colorName,
                iconName: def.icon,
                sortOrder: order,
                keywords: def.keywords,
                seedKey: def.name
            ))
            nextOrder += 1
            changed = true
        }

        if changed {
            do {
                try context.save()
                Log.store.info("Seeded/updated default categories")
            } catch {
                Log.store.error("Failed to seed categories: \(error.localizedDescription, privacy: .public)")
            }
        }

        let all = (try? context.fetch(FetchDescriptor<SpendingCategory>())) ?? []
        CategoryRegistry.refresh(all)
    }
}
