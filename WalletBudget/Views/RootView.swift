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
                SyncEngine.shared.requestSync()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    refreshNotifications()
                    SyncEngine.shared.requestSync()
                }
            }
    }

    /// Rebuilds scheduled reminders, runs the budget-threshold check, and refreshes the widget.
    private func refreshNotifications() {
        NotificationManager.shared.refreshAll(context: context)
        NotificationManager.shared.checkBudgetAlerts(context: context)
        WidgetUpdater.refresh(context: context)
    }

    /// Selected root tab; mutated by the tab bar and by `tabSwipe()` swipes.
    @State private var selection = 0

    private var tabs: some View {
        TabView(selection: $selection) {
            SpendingView()
                .tabItem { Label("Spending", systemImage: "list.bullet") }
                .tag(0)
            SetupGuideView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .orbitSwitchTab)) { note in
            guard let delta = note.object as? Int else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                selection = min(1, max(0, selection + delta))
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AccountStore())
        .modelContainer(for: [Expense.self, SpendingCategory.self], inMemory: true)
}
