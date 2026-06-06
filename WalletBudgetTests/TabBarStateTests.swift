import XCTest
import UIKit
@testable import WalletBudget

/// Unit tests for `TabBarState`, the root floating tab bar's visibility model.
@MainActor
final class TabBarStateTests: XCTestCase {
    /// A fresh state hides nothing: no keyboard, no pushed screens.
    func testInitiallyVisible() {
        let state = TabBarState()
        XCTAssertFalse(state.isHidden)
        XCTAssertFalse(state.isPushed)
    }

    /// A visible bar-hiding screen hides the bar; removing it shows the bar again.
    func testScreenVisibilityHidesAndShows() {
        let state = TabBarState()
        let id = UUID()
        state.setScreen(id, visible: true)
        XCTAssertTrue(state.isHidden)
        XCTAssertTrue(state.isPushed)
        state.setScreen(id, visible: false)
        XCTAssertFalse(state.isHidden)
        XCTAssertFalse(state.isPushed)
    }

    /// During a push, the incoming screen can appear before the outgoing one
    /// disappears (or vice versa): set membership must keep the bar hidden as
    /// long as at least one screen is up, regardless of event order.
    func testOverlappingScreensKeepBarHidden() {
        let state = TabBarState()
        let first = UUID(), second = UUID()
        state.setScreen(first, visible: true)
        state.setScreen(second, visible: true)   // deeper push appears first
        state.setScreen(first, visible: false)   // parent disappears after
        XCTAssertTrue(state.isHidden, "Bar must stay hidden while the deeper screen is up")
        state.setScreen(second, visible: false)
        XCTAssertFalse(state.isHidden)
    }

    /// Removing a screen that was never added is a harmless no-op.
    func testRemovingUnknownScreenIsNoOp() {
        let state = TabBarState()
        state.setScreen(UUID(), visible: false)
        XCTAssertFalse(state.isHidden)
    }

    /// Keyboard notifications hide and show the bar. Posting on the main
    /// thread delivers synchronously to the `.main`-queue observer.
    func testKeyboardNotificationsToggleVisibility() {
        let state = TabBarState()
        NotificationCenter.default.post(name: UIResponder.keyboardWillShowNotification, object: nil)
        XCTAssertTrue(state.keyboardVisible)
        XCTAssertTrue(state.isHidden)
        XCTAssertFalse(state.isPushed, "Keyboard alone must not lock the pager")
        NotificationCenter.default.post(name: UIResponder.keyboardWillHideNotification, object: nil)
        XCTAssertFalse(state.keyboardVisible)
        XCTAssertFalse(state.isHidden)
    }
}
