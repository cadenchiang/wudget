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

    private let presets: [Double] = [500, 600, 700, 800, 900, 1000, 1500, 2000, 3000]

    /// The budget the current draft text represents (0 when blank/invalid).
    private var draftValue: Double {
        Double(draft.filter { $0.isNumber || $0 == "." }) ?? 0
    }

    /// Days in the current month, for the per-day allowance line.
    private var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 30
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // The amount, front and center like the add-transaction flow.
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("$")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.primary)
                    TextField("0", text: $draft)
                        .font(.system(size: 52, weight: .bold))
                        .keyboardType(.decimalPad)
                        .focused($amountFocused)
                        .submitLabel(.done)
                        .onSubmit { commit() }
                        .fixedSize()
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 32)

                // The smart line: what the monthly number means day to day.
                Text(allowanceLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    .opacity(draftValue > 0 ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: draftValue > 0)

                // Quick-set chips, monochrome capsules like the rest of the app.
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(presets, id: \.self) { amount in
                        quickSetChip(amount)
                    }
                }
                .padding(.top, 28)

                Button("No Budget") {
                    Haptics.tap()
                    setBudget(0)
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.top, 24)
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Monthly Budget")
        .navigationBarTitleDisplayMode(.inline)
        .hidesRootTabBar()
        .onChange(of: amountFocused) { _, focused in
            if !focused { commit() }
        }
        .onAppear {
            draft = displayString(for: monthlyBudget)
            amountFocused = true
        }
        .onDisappear { commit() }
    }

    /// "That's $33.33 a day, $233 a week" for the current draft.
    private var allowanceLine: String {
        let day = Self.perDay(monthly: draftValue, daysInMonth: daysInMonth)
        let week = Self.perWeek(monthly: draftValue, daysInMonth: daysInMonth)
        return "That's \(day.asCurrency()) a day, \(week.asCurrency()) a week"
    }

    /// One quick-set capsule; the selected preset renders inverted.
    private func quickSetChip(_ amount: Double) -> some View {
        let selected = draftValue == amount
        return Button {
            Haptics.selection()
            setBudget(amount)
        } label: {
            Text(amount.asCurrency())
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().fill(selected ? Color.primary : Color(.secondarySystemBackground)))
                .foregroundStyle(selected ? Color(.systemBackground) : .primary)
        }
        .buttonStyle(.plain)
    }

    /// Per-day spending allowance for a monthly budget.
    /// - Parameters:
    ///   - monthly: the monthly budget.
    ///   - daysInMonth: days in the month being considered (must be > 0).
    /// - Returns: the daily allowance, or 0 for a non-positive budget/days.
    nonisolated static func perDay(monthly: Double, daysInMonth: Int) -> Double {
        guard monthly > 0, daysInMonth > 0 else { return 0 }
        return monthly / Double(daysInMonth)
    }

    /// Per-week (7-day) spending allowance for a monthly budget.
    /// - Parameters:
    ///   - monthly: the monthly budget.
    ///   - daysInMonth: days in the month being considered (must be > 0).
    /// - Returns: the weekly allowance, or 0 for a non-positive budget/days.
    nonisolated static func perWeek(monthly: Double, daysInMonth: Int) -> Double {
        perDay(monthly: monthly, daysInMonth: daysInMonth) * 7
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
