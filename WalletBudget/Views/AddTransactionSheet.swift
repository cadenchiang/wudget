import SwiftUI
import SwiftData

/// Modal form for manually logging a transaction (fallback when not using the Shortcut).
struct AddTransactionSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var amountText = ""
    @State private var merchant = ""
    @State private var card = ""
    @State private var category = ""
    @State private var date = Date()
    @State private var recurrence: RecurrenceFrequency = .none
    @State private var notes = ""
    @State private var errorMessage: String?
    @State private var showingMerchantPicker = false
    @State private var showingCardPicker = false
    @FocusState private var amountFocused: Bool

    /// Creates the add form.
    /// - Parameter recurrenceDefault: Initial recurrence (e.g. `.monthly` when adding from the
    ///   Recurring screen).
    init(recurrenceDefault: RecurrenceFrequency = .none) {
        _recurrence = State(initialValue: recurrenceDefault)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Purchase") {
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .focused($amountFocused)
                        .submitLabel(.done)
                    selectionRow(
                        label: "Merchant",
                        value: merchant,
                        placeholder: "Choose",
                        item: MerchantLibrary.item(named: merchant),
                        fallbackIcon: "tag.fill"
                    ) { showingMerchantPicker = true }
                }

                Section("Optional") {
                    selectionRow(
                        label: "Card",
                        value: card,
                        placeholder: "Choose",
                        item: CardLibrary.item(named: card),
                        fallbackIcon: "creditcard.fill"
                    ) { showingCardPicker = true }
                    Picker("Category", selection: $category) {
                        Text("Automatic").tag("")
                        ForEach(ExpenseCategorizer.allCategories, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    Picker("Repeat", selection: $recurrence) {
                        ForEach(RecurrenceFrequency.allCases) { frequency in
                            Text(frequency.label).tag(frequency)
                        }
                    }
                    TextField("Add a note", text: $notes, axis: .vertical)
                        .lineLimit(1...4)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear { amountFocused = true }
            .sheet(isPresented: $showingMerchantPicker) {
                LibraryPickerView(title: "Merchant", items: MerchantLibrary.items, fallbackIcon: "tag.fill") { merchant = $0 }
            }
            .sheet(isPresented: $showingCardPicker) {
                LibraryPickerView(title: "Card", items: CardLibrary.items, fallbackIcon: "creditcard.fill") { card = $0 }
            }
        }
        .presentationDragIndicator(.visible)
    }

    /// A tappable form row that opens a library picker, showing the current selection (with its
    /// icon when known) or a placeholder.
    /// - Parameters:
    ///   - label: Row label (e.g. "Merchant").
    ///   - value: The currently selected name (empty when unset).
    ///   - placeholder: Text shown when `value` is empty.
    ///   - item: The matching library item, if the value is a known entry (for its icon/color).
    ///   - fallbackIcon: Icon used for custom values not in the library.
    ///   - action: Opens the corresponding picker.
    private func selectionRow(
        label: String,
        value: String,
        placeholder: String,
        item: LibraryItem?,
        fallbackIcon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(label).foregroundStyle(.primary)
                Spacer()
                if value.isEmpty {
                    Text(placeholder).foregroundStyle(.secondary)
                } else {
                    Image(systemName: item?.systemImage ?? fallbackIcon)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill((item?.color ?? .gray).gradient)
                        )
                    Text(value).foregroundStyle(.primary)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// Validates the form and persists a new `Expense`, dismissing on success.
    ///
    /// On invalid input it sets `errorMessage` (shown inline) and logs the cause; it never
    /// inserts a partial/invalid record.
    private func save() {
        guard let value = CurrencyParser.parse(amountText), value != 0 else {
            errorMessage = "Enter a valid, non-zero amount."
            Log.ui.error("Manual add rejected: bad amount \(amountText, privacy: .public)")
            return
        }
        let cleanMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanMerchant.isEmpty else {
            errorMessage = "Enter a merchant name."
            Log.ui.error("Manual add rejected: empty merchant")
            return
        }

        // An empty category means "Automatic" — let the model derive it from the merchant.
        let chosenCategory = category.isEmpty ? nil : category
        let expense = Expense(amount: value, merchant: cleanMerchant, card: card, date: date, category: chosenCategory, recurrence: recurrence, notes: notes.trimmingCharacters(in: .whitespacesAndNewlines))
        context.insert(expense)
        do {
            try context.save()
            Haptics.success()
            Log.ui.info("Manually added \(expense.amount) at \(cleanMerchant, privacy: .public)")
            dismiss()
        } catch {
            errorMessage = "Could not save. Please try again."
            Log.ui.error("Manual save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

#Preview {
    AddTransactionSheet()
        .modelContainer(for: Expense.self, inMemory: true)
}
