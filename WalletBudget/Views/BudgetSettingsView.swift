import SwiftUI

/// Sub-page of Settings for the monthly budget: the budget amount and whether budgeting is on.
/// Pushed from `SetupGuideView`.
struct BudgetSettingsView: View {
    @AppStorage("budget.monthly") private var monthlyBudget = 0.0
    @AppStorage("budget.enabled") private var budgetEnabled = true

    var body: some View {
        List {
            Section {
                NavigationLink {
                    BudgetEditorView()
                } label: {
                    HStack {
                        Text("Monthly Budget")
                        Spacer()
                        Text(monthlyBudget > 0 ? monthlyBudget.asCurrency() : "None")
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle("Use a Budget", isOn: $budgetEnabled)
            } footer: {
                Text("Set a monthly spending limit and Orbit will track your progress against it.")
            }
        }
        .navigationTitle("Budget")
        .navigationBarTitleDisplayMode(.inline)
        .hidesRootTabBar()
    }
}
