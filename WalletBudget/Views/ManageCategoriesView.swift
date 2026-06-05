import SwiftUI
import SwiftData

/// Lists the user's categories with reorder, delete (reassigning to "Other"), edit, and add.
struct ManageCategoriesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SpendingCategory.sortOrder) private var categories: [SpendingCategory]
    @State private var editing: SpendingCategory?
    @State private var addingNew = false

    var body: some View {
        List {
            ForEach(categories) { category in
                Button { editing = category } label: { row(category) }
                    .buttonStyle(.plain)
            }
            .onDelete(perform: delete)
            .onMove(perform: move)

            Text("Tap a category to edit it. Swipe left to delete one; its transactions move to Other.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 32, bottom: 16, trailing: 32))
        }
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { addingNew = true } label: { Image(systemName: "plus") }
                    .tint(.primary)
                    .accessibilityLabel("Add category")
            }
        }
        .sheet(item: $editing) { CategoryEditorView(category: $0) }
        .sheet(isPresented: $addingNew) { CategoryEditorView(category: nil) }
    }

    /// A category row: colored icon tile + name.
    private func row(_ category: SpendingCategory) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(CategoryCatalog.color(named: category.colorName).gradient)
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: category.iconName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
            Text(category.name).foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    /// Deletes categories (except "Other"), reassigning their transactions to "Other".
    private func delete(at offsets: IndexSet) {
        for category in offsets.map({ categories[$0] }) where category.name != ExpenseCategorizer.uncategorized {
            reassignExpenses(from: category.name, to: ExpenseCategorizer.uncategorized)
            context.delete(category)
        }
        persist()
    }

    /// Reorders categories by rewriting `sortOrder`.
    private func move(from source: IndexSet, to destination: Int) {
        var ordered = categories
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, category) in ordered.enumerated() {
            category.sortOrder = index
        }
        persist()
    }

    /// Moves all expenses from `old` category name to `new`.
    private func reassignExpenses(from old: String, to new: String) {
        let descriptor = FetchDescriptor<Expense>(predicate: #Predicate { $0.category == old })
        if let affected = try? context.fetch(descriptor) {
            for expense in affected { expense.category = new }
        }
    }

    /// Saves and refreshes the registry.
    private func persist() {
        do {
            try context.save()
            CategorySeeder.seedAndRefresh(context: context)
        } catch {
            Log.ui.error("Failed to update categories: \(error.localizedDescription, privacy: .public)")
        }
    }
}

#Preview {
    NavigationStack {
        ManageCategoriesView()
    }
    .modelContainer(for: [Expense.self, SpendingCategory.self], inMemory: true)
}
