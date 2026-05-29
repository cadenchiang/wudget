import SwiftUI
import SwiftData

/// Detail screen for a single transaction, styled after the Apple Card transaction view:
/// a large amount with merchant and date, a details card, and an editable category picker.
struct TransactionDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var expense: Expense
    @State private var showingCardPicker = false
    @State private var confirmingDelete = false

    /// "8/30/25, 9:41 AM"-style timestamp.
    private var dateString: String {
        expense.date.formatted(
            Date.FormatStyle()
                .month(.defaultDigits).day().year(.twoDigits)
                .hour().minute()
        )
    }

    /// Card label, falling back to "Apple Pay" when no card name was captured.
    private var cardText: String {
        expense.card.isEmpty ? "Apple Pay" : expense.card
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                detailsCard
                notesCard
                reportCard
                deleteButton
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this transaction?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteExpense() }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: expense.category) { _, _ in
            Haptics.selection()
            save(describing: "category")
        }
        .onChange(of: expense.notes) { _, _ in
            save(describing: "note")
        }
        .sheet(isPresented: $showingCardPicker) {
            LibraryPickerView(title: "Card", items: CardLibrary.items, fallbackIcon: "creditcard.fill") { newCard in
                expense.card = newCard
                save(describing: "card")
            }
        }
    }

    /// Centered amount, merchant, and timestamp.
    private var header: some View {
        VStack(spacing: 6) {
            Text(expense.amount.asCurrency())
                .font(.system(size: 52, weight: .bold))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(expense.merchant.isEmpty ? "Unknown" : expense.merchant)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(dateString)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity)
    }

    /// Card with the editable card-used and category rows.
    private var detailsCard: some View {
        VStack(spacing: 0) {
            cardRow
            Divider().padding(.leading, 16)
            categoryRow
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    /// "Card Used" label with a button that opens the card picker.
    private var cardRow: some View {
        Button {
            showingCardPicker = true
        } label: {
            HStack(spacing: 6) {
                Text("Card Used").foregroundStyle(.primary)
                Spacer()
                if let item = CardLibrary.item(named: expense.card) {
                    Image(systemName: item.systemImage).foregroundStyle(item.color)
                }
                Text(cardText).foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .tint(.primary)
        .padding(16)
    }

    /// "Category" label with a menu to reassign the category (icons + checkmark on current).
    private var categoryRow: some View {
        HStack {
            Text("Category")
            Spacer()
            Menu {
                Picker("Category", selection: $expense.category) {
                    ForEach(ExpenseCategorizer.allCategories, id: \.self) { category in
                        Label {
                            Text(category)
                        } icon: {
                            Image(uiImage: CategoryStyle.tileImage(for: category))
                                .renderingMode(.original)
                        }
                        .tag(category)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: CategoryStyle.icon(for: expense.category))
                        .foregroundStyle(CategoryStyle.color(for: expense.category))
                    Text(expense.category)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.primary)
        }
        .padding(16)
    }

    /// Decorative "Report an Issue" card matching the reference layout.
    private var reportCard: some View {
        Button {
            Log.ui.info("Report an Issue tapped for \(expense.merchant, privacy: .public)")
        } label: {
            Text("Report an Issue")
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    /// Editable note card.
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("Add a note", text: $expense.notes, axis: .vertical)
                .lineLimit(1...6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    /// Destructive "Delete Transaction" button (confirmed via dialog).
    private var deleteButton: some View {
        Button { confirmingDelete = true } label: {
            Text("Delete Transaction")
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    /// Deletes the expense, saves, and pops back.
    private func deleteExpense() {
        Haptics.tap(.rigid)
        context.delete(expense)
        do {
            try context.save()
            Log.ui.info("Deleted transaction at \(expense.merchant, privacy: .public)")
            dismiss()
        } catch {
            Log.ui.error("Failed to delete transaction: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Persists an edit to the expense and logs the outcome.
    /// - Parameter field: The field that changed (for the log message).
    private func save(describing field: String) {
        do {
            try context.save()
            Log.ui.info("Updated \(field, privacy: .public) for \(expense.merchant, privacy: .public)")
        } catch {
            Log.ui.error("Failed to save \(field, privacy: .public) change: \(error.localizedDescription, privacy: .public)")
        }
    }
}
