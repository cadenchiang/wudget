import SwiftUI

/// Dedicated screen for setting the monthly budget: a focused amount field plus quick presets.
///
/// Typing only mutates a local `draft` string; the parsed value is written to `@AppStorage`
/// (`budget.monthly`) when the user commits (Done / return) or leaves the screen. Writing storage
/// on every keystroke made typing slow and glitchy, because other screens observe `budget.monthly`
/// and recompute (the chart, the pace projection) on each change. Keeping edits local fixes that.
struct BudgetEditorView: View {
    @AppStorage("budget.monthly") private var monthlyBudget = 0.0
    @FocusState private var amountFocused: Bool
    @State private var draft = ""

    private let presets: [Double] = [500, 1000, 1500, 2000, 3000, 5000]

    /// The budget the current draft text represents (0 when blank/invalid).
    private var draftValue: Double {
        Double(draft.filter { $0.isNumber || $0 == "." }) ?? 0
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 4) {
                    Text("$")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("0", text: $draft)
                        .font(.title2.weight(.semibold))
                        .keyboardType(.decimalPad)
                        .focused($amountFocused)
                        .submitLabel(.done)
                        .onSubmit { commit() }
                }
            } footer: {
                Text("Your target spending per month, shown as a line on the chart. Week and Year views scale this automatically.")
            }

            Section("Quick Set") {
                ForEach(presets, id: \.self) { amount in
                    Button {
                        Haptics.selection()
                        setBudget(amount)
                    } label: {
                        HStack {
                            Text(amount.asCurrency())
                                .foregroundStyle(.primary)
                            Spacer()
                            if draftValue == amount {
                                Image(systemName: "checkmark").foregroundStyle(.primary)
                            }
                        }
                    }
                }
                Button(role: .destructive) {
                    setBudget(0)
                } label: {
                    Text("No Budget")
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Monthly Budget")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: amountFocused) { _, focused in
            if !focused { commit() }
        }
        .onAppear {
            draft = displayString(for: monthlyBudget)
            amountFocused = true
        }
        .onDisappear { commit() }
    }

    /// Writes the draft's parsed value to storage (idempotent; safe to call repeatedly)
    /// and marks the prefs row dirty for cloud sync.
    private func commit() {
        let value = draftValue
        if monthlyBudget != value {
            monthlyBudget = value
            SyncEngine.shared.prefsChanged()
        }
    }

    /// Sets the budget from a preset/clear action, syncs the field text, and dismisses the keyboard.
    /// - Parameter amount: The budget to store (0 clears it).
    private func setBudget(_ amount: Double) {
        draft = displayString(for: amount)
        monthlyBudget = amount
        SyncEngine.shared.prefsChanged()
        amountFocused = false
    }

    /// String shown in the field for a stored amount: empty for 0, no trailing ".0" for integers.
    /// - Parameter amount: The stored budget value.
    /// - Returns: The text to seed the field with.
    private func displayString(for amount: Double) -> String {
        guard amount > 0 else { return "" }
        return amount.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }
}
