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

        if existing.isEmpty {
            for (index, def) in CategoryCatalog.defaults.enumerated() {
                context.insert(SpendingCategory(
                    name: def.name,
                    colorName: def.colorName,
                    iconName: def.icon,
                    sortOrder: index,
                    keywords: def.keywords
                ))
            }
            do {
                try context.save()
                Log.store.info("Seeded \(CategoryCatalog.defaults.count) default categories")
            } catch {
                Log.store.error("Failed to seed categories: \(error.localizedDescription, privacy: .public)")
            }
        }

        let all = (try? context.fetch(FetchDescriptor<SpendingCategory>())) ?? []
        CategoryRegistry.refresh(all)
    }
}
