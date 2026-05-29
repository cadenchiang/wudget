import SwiftUI
import SwiftData

/// Top-level tab container: the spending log and the settings/setup screen.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        tabs
            .task {
                CategorySeeder.seedAndRefresh(context: context)
                NotificationManager.shared.refreshAuthorization()
                refreshNotifications()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refreshNotifications() }
            }
    }

    /// Rebuilds scheduled reminders and runs the budget-threshold check.
    private func refreshNotifications() {
        NotificationManager.shared.refreshAll(context: context)
        NotificationManager.shared.checkBudgetAlerts(context: context)
    }

    private var tabs: some View {
        TabView {
            SpendingView()
                .tabItem { Label("Spending", systemImage: "list.bullet") }
            SetupGuideView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Expense.self, SpendingCategory.self], inMemory: true)
}
