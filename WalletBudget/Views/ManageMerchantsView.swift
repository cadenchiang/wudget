import SwiftUI
import SwiftData

/// Lists every merchant appearing on the user's transactions, most used first,
/// with rename: renaming a merchant updates ALL of its transactions (each one
/// stamped so the rename wins last-write-wins sync merges). Pushed from
/// Tracking settings, parallel to Categories.
struct ManageMerchantsView: View {
    @Environment(\.modelContext) private var context
    @Query private var expenses: [Expense]
    /// The merchant currently being renamed; non-nil shows the rename alert.
    @State private var renaming: MerchantGroup?
    @State private var nameInput = ""

    /// One distinct merchant and how many transactions carry it.
    struct MerchantGroup: Identifiable {
        /// Raw stored merchant value (empty string for unknown).
        let name: String
        /// Number of transactions with this merchant.
        let count: Int
        var id: String { name }
        /// What the row shows; empty names read "Unknown" like the lists do.
        var displayName: String { name.isEmpty ? "Unknown" : name }
    }

    /// Distinct merchants, most used first (ties alphabetical).
    private var groups: [MerchantGroup] {
        Dictionary(grouping: expenses, by: \.merchant)
            .map { MerchantGroup(name: $0.key, count: $0.value.count) }
            .sorted { $0.count == $1.count ? $0.displayName < $1.displayName : $0.count > $1.count }
    }

    var body: some View {
        List {
            if groups.isEmpty {
                Text("Merchants appear here once you've logged transactions.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(groups) { group in
                    Button {
                        nameInput = group.name
                        renaming = group
                    } label: {
                        row(group)
                    }
                    .buttonStyle(.plain)
                }

                Text("Tap a merchant to rename it. The new name is applied to all of its transactions; renaming onto an existing merchant merges them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 32, bottom: 16, trailing: 32))
            }
        }
        .navigationTitle("Merchants")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Rename Merchant", isPresented: renameAlertShown, presenting: renaming) { group in
            TextField("Merchant name", text: $nameInput)
            Button("Save") { rename(group, to: nameInput) }
            Button("Cancel", role: .cancel) {}
        } message: { group in
            Text("Renames \(group.displayName) on \(group.count) transaction\(group.count == 1 ? "" : "s").")
        }
    }

    /// Binding that shows the rename alert whenever a merchant is selected.
    private var renameAlertShown: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }

    /// A merchant row: logo tile, name, transaction count, chevron.
    private func row(_ group: MerchantGroup) -> some View {
        HStack(spacing: 12) {
            MerchantLogoTile(merchant: group.name, size: 36, cornerRadius: 9)
            VStack(alignment: .leading, spacing: 2) {
                Text(group.displayName)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(group.count) transaction\(group.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        // Whole row tappable (a plain-style Button only hit-tests its label).
        .contentShape(Rectangle())
    }

    /// Applies the rename to every transaction carrying the old merchant name.
    ///
    /// Each affected expense is stamped (`updatedAt`) so the rename wins LWW
    /// sync merges; no-ops on empty or unchanged input.
    private func rename(_ group: MerchantGroup, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != group.name else { return }
        let old = group.name
        let descriptor = FetchDescriptor<Expense>(predicate: #Predicate { $0.merchant == old })
        do {
            let affected = try context.fetch(descriptor)
            for expense in affected {
                expense.merchant = trimmed
                expense.updatedAt = Date()
            }
            try context.save()
            SyncEngine.shared.requestSync()
            Haptics.success()
            Log.ui.info("""
            Renamed merchant "\(group.displayName, privacy: .public)" → \
            "\(trimmed, privacy: .public)" on \(affected.count) transactions
            """)
        } catch {
            Log.ui.error("Merchant rename failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

#Preview {
    NavigationStack {
        ManageMerchantsView()
    }
    .modelContainer(for: [Expense.self, SpendingCategory.self], inMemory: true)
}
