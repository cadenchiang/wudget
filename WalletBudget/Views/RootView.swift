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

    /// Pager state (selection + live drag offset) shared with the root screens'
    /// swipe gestures via the environment.
    @State private var pager = TabPager()
    /// Namespace for the tab bar's sliding selection highlight.
    @Namespace private var tabNamespace

    /// One shared curve for every way the tabs can move (tap, swipe), so the
    /// pager slide and the highlight slide always travel together.
    private static let tabAnimation: Animation = .snappy(duration: 0.32, extraBounce: 0)

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
            .offset(x: pagerOffset(width: geo.size.width))
            .onAppear { pager.width = geo.size.width }
            .onChange(of: geo.size.width) { _, width in pager.width = width }
        }
        .environment(pager)
        .overlay(alignment: .bottom) { tabBar }
    }

    /// Pager x-offset: the selected page plus any in-flight drag, with rubber-
    /// band resistance when dragging past the first/last tab.
    private func pagerOffset(width: CGFloat) -> CGFloat {
        var drag = pager.dragOffset
        if (pager.selection == 0 && drag > 0) || (pager.selection == pager.count - 1 && drag < 0) {
            drag /= 3
        }
        return -CGFloat(pager.selection) * width + drag
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
            withAnimation(Self.tabAnimation) { pager.dragOffset = 0; pager.selection = index }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .frame(height: 20)
                Text(title)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
            }
            .foregroundStyle(pager.selection == index ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
            .frame(width: 92, height: 48)
            .background {
                if pager.selection == index {
                    Capsule()
                        .fill(Color.primary.opacity(0.1))
                        .matchedGeometryEffect(id: "selectedTab", in: tabNamespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(pager.selection == index ? .isSelected : [])
    }
}

#Preview {
    RootView()
        .environment(AccountStore())
        .modelContainer(for: [Expense.self, SpendingCategory.self], inMemory: true)
}
