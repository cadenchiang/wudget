import SwiftUI
import UIKit

/// Shared visibility state for the root floating tab bar.
///
/// The bar hides while the keyboard is up (typing anywhere) and while any
/// screen that declares `hidesRootTabBar()` is visible (pushed Settings
/// sub-pages). Visible screens are tracked as a set of identities rather than
/// a counter: during a push or pop, the incoming view's `onAppear` and the
/// outgoing view's `onDisappear` fire in no guaranteed order, which would
/// corrupt a plain count but is harmless to set membership.
@Observable
@MainActor
final class TabBarState {
    /// Identities of currently visible screens that hide the bar.
    private var hidingScreens: Set<UUID> = []
    /// Whether the keyboard is currently on screen.
    private(set) var keyboardVisible = false

    /// Whether the floating bar should be hidden right now.
    var isHidden: Bool { keyboardVisible || !hidingScreens.isEmpty }

    /// Whether a bar-hiding screen (a pushed sub-page) is on screen. The root
    /// pager locks its horizontal swipe while this is true, so swipes inside a
    /// sub-page pop back instead of dragging between tabs.
    var isPushed: Bool { !hidingScreens.isEmpty }

    /// Keyboard show/hide observer tokens, removed on deinit (which is
    /// nonisolated, hence the unsafe opt-out; tokens are only mutated in init).
    private nonisolated(unsafe) var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.keyboardVisible = true }
        })
        observers.append(center.addObserver(
            forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.keyboardVisible = false }
        })
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Records a bar-hiding screen entering or leaving the screen.
    /// - Parameters:
    ///   - id: The screen instance's stable identity.
    ///   - visible: `true` on appear, `false` on disappear.
    func setScreen(_ id: UUID, visible: Bool) {
        if visible {
            hidingScreens.insert(id)
        } else {
            hidingScreens.remove(id)
        }
    }
}

/// Hides the root floating tab bar for as long as the modified screen is
/// visible. Safe outside `RootView`'s environment (welcome, previews): with no
/// `TabBarState` present it does nothing.
private struct HidesRootTabBar: ViewModifier {
    @Environment(TabBarState.self) private var tabBar: TabBarState?
    /// Stable identity for this screen instance across appear/disappear.
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear { tabBar?.setScreen(id, visible: true) }
            .onDisappear { tabBar?.setScreen(id, visible: false) }
    }
}

extension View {
    /// Marks a pushed screen as full-bleed: the root floating tab bar slides
    /// away while it is visible and returns when it pops.
    func hidesRootTabBar() -> some View {
        modifier(HidesRootTabBar())
    }
}
