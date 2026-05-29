import SwiftUI
import SwiftData

/// Top-level tab container: the spending log and the settings/setup screen.
struct RootView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        tabs
            .task { CategorySeeder.seedAndRefresh(context: context) }
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
