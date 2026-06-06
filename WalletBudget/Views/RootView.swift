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

    /// Selected root tab; bound to the paged TabView and the custom tab bar.
    @State private var selection = 0
    /// Namespace for the tab bar's sliding selection highlight.
    @Namespace private var tabNamespace

    /// One shared curve for every way the tabs can move (tap, swipe), so the
    /// pager slide and the highlight slide always travel together.
    private static let tabAnimation: Animation = .snappy(duration: 0.32, extraBounce: 0)

    /// Both roots side by side in a pager, so switching tabs slides smoothly
    /// (a system TabView snaps with no animation). The floating glass pill
    /// below mirrors the iOS 26 tab-bar look.
    /// Native paged TabView (UIPageViewController under the hood): swiping
    /// tracks the finger with the system's own physics — no custom gesture
    /// math. The page dots are hidden; our floating bar is the indicator.
    private var tabs: some View {
        TabView(selection: $selection) {
            SpendingView()
                .tag(0)
            SetupGuideView()
                .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .overlay(alignment: .bottom) { tabBar }
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

    /// One tab pill: icon + title. Every pill is the exact same size; the
    /// selected highlight is a single capsule that SLIDES between pills
    /// (matched geometry) on the same curve as the page transition.
    private func tabButton(_ index: Int, icon: String, title: String) -> some View {
        Button {
            Haptics.tap()
            withAnimation(Self.tabAnimation) { selection = index }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .frame(height: 20)
                Text(title)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
            }
            .foregroundStyle(selection == index ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
            .frame(width: 92, height: 48)
            .background {
                if selection == index {
                    Capsule()
                        .fill(Color.primary.opacity(0.1))
                        .matchedGeometryEffect(id: "selectedTab", in: tabNamespace)
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
