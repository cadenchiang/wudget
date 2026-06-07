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
    /// Bar visibility (hidden while typing or inside a pushed sub-page),
    /// shared with every screen via the environment.
    @State private var tabBarState = TabBarState()
    /// Namespace for the tab bar's sliding selection highlight.
    @Namespace private var tabNamespace

    /// One shared curve for every way the tabs can move (tap, swipe), so the
    /// pager slide and the highlight slide always travel together.
    private static let tabAnimation: Animation = .snappy(duration: 0.32, extraBounce: 0)

    /// Both roots side by side in a pager, so switching tabs slides smoothly
    /// (a system TabView snaps with no animation). The floating glass pill
    /// below mirrors the iOS 26 tab-bar look.
    /// Native paged TabView: swiping tracks the finger with the system's own
    /// physics — no custom gesture math. The page dots are hidden; our
    /// floating bar is the indicator.
    ///
    /// Each page keeps its OWN NavigationStack (a single root stack was tried
    /// 2026-06-06 and reverted: it broke every page's safe-area layout).
    /// While a sub-page is pushed, the pager's swipe is disabled two ways —
    /// `scrollDisabled` (native SwiftUI pager) and `PagerScrollLock` (UIKit
    /// UIPageViewController backing) — so the edge swipe belongs to the
    /// navigation stack and pops back to Settings instead of dragging the
    /// pager to Spending.
    ///
    /// `ignoresSafeArea` is required: the pager otherwise confines each page
    /// to the safe area, so page backgrounds (e.g. Settings' grouped gray)
    /// stop short of the screen edges and the white window shows through.
    /// Each page's own NavigationStack re-derives its safe area, so list
    /// insets and top chrome still land correctly. The tab bar lives beside
    /// the pager in the ZStack (not an overlay on the expanded view) so it
    /// keeps its own safe-area placement above the home indicator.
    private var tabs: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selection) {
                SpendingView()
                    .background(PagerScrollLock(locked: tabBarState.isPushed))
                    .tag(0)
                SetupGuideView()
                    .background(PagerScrollLock(locked: tabBarState.isPushed))
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .scrollDisabled(tabBarState.isPushed)
            .ignoresSafeArea()
            tabBar
                .opacity(tabBarState.isHidden ? 0 : 1)
                .offset(y: tabBarState.isHidden ? 90 : 0)
                .allowsHitTesting(!tabBarState.isHidden)
                .animation(.spring(duration: 0.32, bounce: 0), value: tabBarState.isHidden)
        }
        .environment(tabBarState)
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

/// Disables the pager's swipe at the UIKit level while a sub-page is pushed.
///
/// Complements `scrollDisabled` on the TabView: whichever backing the paged
/// TabView uses on this OS (native SwiftUI scrolling, or UIPageViewController
/// with its internal `_UIQueuingScrollView`), one of the two mechanisms takes
/// hold, so the edge-swipe-back always belongs to the navigation stack.
private struct PagerScrollLock: UIViewRepresentable {
    /// Whether the pager's swipe is currently disabled.
    let locked: Bool

    func makeUIView(context: Context) -> LockView { LockView() }

    func updateUIView(_ view: LockView, context: Context) {
        view.apply(locked: locked)
    }

    /// Invisible view that finds and toggles the enclosing pager scroll view.
    final class LockView: UIView {
        /// Last requested state, re-applied once the view lands in a window
        /// (the scroll view isn't reachable before then).
        private var locked = false

        override func didMoveToWindow() {
            super.didMoveToWindow()
            apply(locked: locked)
        }

        /// Walks the whole superview chain and toggles EVERY ancestor scroll
        /// view (the only scrollable ancestors of a page root are the pager's
        /// internals, whatever class the OS implements them with — plain
        /// scroll view, queuing scroll view, or collection view). Logs what
        /// it touches so a silent miss is diagnosable from the console.
        func apply(locked: Bool) {
            self.locked = locked
            guard window != nil else { return }
            var found = 0
            var ancestor = superview
            while let view = ancestor {
                if let scroll = view as? UIScrollView {
                    scroll.isScrollEnabled = !locked
                    found += 1
                }
                ancestor = view.superview
            }
            Log.ui.debug("PagerScrollLock locked=\(locked) toggled \(found) ancestor scroll view(s)")
        }
    }
}

#Preview {
    RootView()
        .environment(AccountStore())
        .modelContainer(for: [Expense.self, SpendingCategory.self], inMemory: true)
}
