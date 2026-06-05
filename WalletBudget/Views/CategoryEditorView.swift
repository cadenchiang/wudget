import SwiftUI
import SwiftData

/// Add or edit a category: name, color, and icon. On save it persists, keeps `CategoryRegistry`
/// in sync, and (when renaming) reassigns existing transactions to the new name.
struct CategoryEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// The category being edited, or `nil` when adding a new one.
    private let existing: SpendingCategory?

    @State private var name: String
    @State private var colorName: String
    @State private var iconName: String
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 12)]

    init(category: SpendingCategory?) {
        self.existing = category
        _name = State(initialValue: category?.name ?? "")
        _colorName = State(initialValue: category?.colorName ?? "blue")
        _iconName = State(initialValue: category?.iconName ?? "tag.fill")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(CategoryCatalog.color(named: colorName).gradient)
                            .frame(width: 60, height: 60)
                            .overlay {
                                Image(systemName: iconName)
                                    .font(.system(size: 26, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        Spacer()
                    }
                    TextField("Name", text: $name)
                }

                Section("Color") { colorGrid }
                Section("Icon") { iconGrid }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle(existing == nil ? "New Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
        }
    }

    private var colorGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(CategoryCatalog.colorChoices, id: \.self) { choice in
                Circle()
                    .fill(CategoryCatalog.color(named: choice))
                    .frame(width: 36, height: 36)
                    .overlay {
                        if choice == colorName {
                            Image(systemName: "checkmark").font(.subheadline.bold()).foregroundStyle(.white)
                        }
                    }
                    .onTapGesture { colorName = choice }
            }
        }
        .padding(.vertical, 4)
    }

    private var iconGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(CategoryCatalog.iconChoices, id: \.self) { choice in
                Image(systemName: choice)
                    .font(.system(size: 18))
                    .foregroundStyle(choice == iconName ? Color.white : Color.primary)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(choice == iconName ? CategoryCatalog.color(named: colorName) : Color(.tertiarySystemFill))
                    )
                    .onTapGesture { iconName = choice }
            }
        }
        .padding(.vertical, 4)
    }

    /// Validates and persists the category, updating existing transactions on rename.
    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { errorMessage = "Enter a name."; return }

        // Reject duplicate names (case-insensitive), ignoring the category being edited.
        let all = (try? context.fetch(FetchDescriptor<SpendingCategory>())) ?? []
        if all.contains(where: { $0 !== existing && $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            errorMessage = "A category named “\(trimmed)” already exists."
            return
        }

        if let existing {
            if existing.name != trimmed {
                reassignExpenses(from: existing.name, to: trimmed)
                existing.name = trimmed
            }
            existing.colorName = colorName
            existing.iconName = iconName
        } else {
            let nextOrder = (all.map(\.sortOrder).max() ?? -1) + 1
            context.insert(SpendingCategory(name: trimmed, colorName: colorName, iconName: iconName, sortOrder: nextOrder))
        }

        do {
            try context.save()
            CategorySeeder.seedAndRefresh(context: context)
            Log.ui.info("Saved category \(trimmed, privacy: .public)")
            dismiss()
        } catch {
            errorMessage = "Couldn't save. Try again."
            Log.ui.error("Failed to save category: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Moves all expenses from `old` category name to `new`, stamping each so the
    /// reassignment wins last-write-wins sync merges.
    private func reassignExpenses(from old: String, to new: String) {
        let descriptor = FetchDescriptor<Expense>(predicate: #Predicate { $0.category == old })
        if let affected = try? context.fetch(descriptor) {
            for expense in affected {
                expense.category = new
                expense.updatedAt = Date()
            }
            SyncEngine.shared.requestSync()
        }
    }
}
