import SwiftUI
import SwiftData

/// Step-by-step sheet for manually logging a transaction (fallback when not using the Shortcut),
/// presented on frosted glass so the screen behind ghosts through. Numbered steps walk through
/// amount → merchant → optional details, with one big Add pill pinned at the bottom that stays
/// dimmed until the required steps are filled.
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
    /// Whether the optional details step is expanded. Collapsed by default so the sheet opens
    /// clean; auto-expanded when a default is pre-filled so the caller's preset is visible.
    @State private var showDetails: Bool
    @FocusState private var amountFocused: Bool

    /// Creates the add sheet.
    /// - Parameters:
    ///   - recurrenceDefault: Initial recurrence (e.g. `.monthly` when adding from the Repeat screen).
    ///   - categoryDefault: Initial category (e.g. "Subscription" when adding from the Repeat
    ///     screen). Empty means "Automatic" (derived from the merchant).
    init(recurrenceDefault: RecurrenceFrequency = .none, categoryDefault: String = "") {
        _recurrence = State(initialValue: recurrenceDefault)
        _category = State(initialValue: categoryDefault)
        _showDetails = State(initialValue: recurrenceDefault != .none || !categoryDefault.isEmpty)
    }

    /// Whether the required steps (a parseable amount and a merchant) are complete.
    private var canSave: Bool {
        CurrencyParser.parse(amountText).map { $0 != 0 } == true
            && !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    amountStep
                    merchantStep
                    detailsStep
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            addButton
        }
        .presentationBackground(.ultraThinMaterial)
        .presentationCornerRadius(36)
        .presentationDragIndicator(.visible)
        .onAppear { amountFocused = true }
        .sheet(isPresented: $showingMerchantPicker) {
            LibraryPickerView(title: "Merchant", items: MerchantLibrary.items, fallbackIcon: "tag.fill") { merchant = $0 }
        }
        .sheet(isPresented: $showingCardPicker) {
            LibraryPickerView(title: "Card", items: CardLibrary.items, fallbackIcon: "creditcard.fill", style: .list) { card = $0 }
        }
    }

    /// Close button and centered title, like a setup flow.
    private var header: some View {
        ZStack {
            Text("Add a transaction")
                .font(.headline)
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(.thinMaterial))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 16)
    }

    /// Step 1: the amount, as one huge focused field.
    private var amountStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepLabel(1, "Enter the amount.")
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("$")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(amountText.isEmpty ? .secondary : .primary)
                TextField("0", text: $amountText)
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .font(.system(size: 44, weight: .bold))
            }
        }
    }

    /// Step 2: the merchant, as a chip that opens the picker.
    private var merchantStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepLabel(2, "Where was it?")
            Button {
                showingMerchantPicker = true
            } label: {
                HStack(spacing: 10) {
                    if merchant.isEmpty {
                        Text("Choose a merchant")
                            .foregroundStyle(.secondary)
                    } else {
                        MerchantLogoTile(merchant: merchant, size: 26, cornerRadius: 7)
                        Text(merchant)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.2), lineWidth: 1))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    /// Step 3 (optional): card, category, date, repeat, and note as plain hairline rows.
    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showDetails.toggle() }
            } label: {
                HStack(spacing: 8) {
                    stepLabel(3, "Details")
                    Text("optional")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(showDetails ? 180 : 0))
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showDetails {
                VStack(spacing: 0) {
                    detailRow("Card", value: card.isEmpty ? "Choose" : card) { showingCardPicker = true }
                    Divider()
                    HStack {
                        Text("Category")
                        Spacer()
                        Picker("Category", selection: $category) {
                            Text("Automatic").tag("")
                            ForEach(ExpenseCategorizer.allCategories, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .tint(.secondary)
                    }
                    .padding(.vertical, 6)
                    Divider()
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .padding(.vertical, 10)
                    Divider()
                    HStack {
                        Text("Repeat")
                        Spacer()
                        Picker("Repeat", selection: $recurrence) {
                            ForEach(RecurrenceFrequency.allCases) { frequency in
                                Text(frequency.label).tag(frequency)
                            }
                        }
                        .tint(.secondary)
                    }
                    .padding(.vertical, 6)
                    Divider()
                    TextField("Add a note", text: $notes, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(.vertical, 14)
                }
                .padding(.top, 8)
                .transition(.opacity)
            }
        }
    }

    /// A numbered step heading: a thin circled digit and a bold prompt.
    private func stepLabel(_ number: Int, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "\(number).circle")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }

    /// The big Add pill pinned at the bottom, dimmed until the required steps are filled.
    private var addButton: some View {
        Button {
            save()
        } label: {
            Text("Add")
                .font(.headline)
                .foregroundStyle(Color(.systemBackground))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Capsule().fill(Color.primary))
                .opacity(canSave ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .animation(.easeInOut(duration: 0.15), value: canSave)
    }

    /// A details row that opens a picker, showing the current selection or a placeholder.
    private func detailRow(_ label: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label).foregroundStyle(.primary)
                Spacer()
                Text(value).foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
