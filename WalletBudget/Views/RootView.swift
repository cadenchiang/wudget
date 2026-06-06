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

    /// Both roots side by side in a pager, so switching tabs slides smoothly
    /// (a system TabView snaps with no animation). The floating glass pill
    /// below mirrors the iOS 26 tab-bar look.
    private var tabs: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                SpendingView()
                    .frame(width: geo.size.width)
                SetupGuideView()
                    .frame(width: geo.size.width)
            }
            .offset(x: -CGFloat(selection) * geo.size.width)
        }
        .overlay(alignment: .bottom) { tabBar }
        .onReceive(NotificationCenter.default.publisher(for: .orbitSwitchTab)) { note in
            guard let delta = note.object as? Int else { return }
            withAnimation(.spring(duration: 0.38, bounce: 0.12)) {
                selection = min(1, max(0, selection + delta))
            }
        }
    }

    /// Floating glass tab bar (two pills) hovering at the bottom of the pager.
    private var tabBar: some View {
        let bar = HStack(spacing: 2) {
            tabButton(0, icon: "list.bullet", title: "Spending")
            tabButton(1, icon: "gearshape", title: "Settings")
        }
        .padding(4)

        return Group {
            if #available(iOS 26.0, *) {
                bar.glassEffect(.regular.interactive(), in: .capsule)
            } else {
                bar
                    .background(Capsule().fill(.ultraThinMaterial))
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            }
        }
        .padding(.bottom, 4)
    }

    /// One tab pill: icon + title, emphasized when selected.
    private func tabButton(_ index: Int, icon: String, title: String) -> some View {
        Button {
            Haptics.tap()
            withAnimation(.spring(duration: 0.38, bounce: 0.12)) { selection = index }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                Text(title)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(selection == index ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
            .frame(width: 86)
            .padding(.vertical, 8)
            .background {
                if selection == index {
                    Capsule().fill(Color.primary.opacity(0.08))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selection == index ? .isSelected : [])
    }
}

#Preview {
    RootView()
        .environment(AccountStore())
        .modelContainer(for: [Expense.self, SpendingCategory.self], inMemory: true)
}
