import SwiftUI

/// Pins top chrome above a scroll view.
///
/// On iOS 26+ this uses `.safeAreaBar(edge: .top)`, which gives the native scroll-edge effect:
/// content scrolling beneath the bar progressively blurs/fades away (matching the system look).
/// We let the system render that effect rather than layering our own solid background, which had
/// caused a flicker when the content under the bar changed. On earlier OSes (no scroll-edge
/// effect) we fall back to a plain `.safeAreaInset` with a matching solid background.
struct TopChromeBar<Bar: View>: ViewModifier {
    @ViewBuilder var bar: () -> Bar

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.safeAreaBar(edge: .top, spacing: 0) {
                bar()
            }
        } else {
            content.safeAreaInset(edge: .top, spacing: 0) {
                bar()
                    .background(Color(.systemGroupedBackground), ignoresSafeAreaEdges: .top)
            }
        }
    }
}

extension View {
    /// Applies `TopChromeBar` with the given bar content.
    /// - Parameter bar: The chrome rendered at the top edge.
    func topChromeBar<Bar: View>(@ViewBuilder _ bar: @escaping () -> Bar) -> some View {
        modifier(TopChromeBar(bar: bar))
    }
}

/// Shared state for the root tab pager: the selection plus the LIVE drag
/// translation, so swipes on the root screens move the pager with the finger
/// instead of animating only after release.
@Observable @MainActor
final class TabPager {
    /// Selected tab index.
    var selection = 0
    /// Live horizontal translation of an in-flight tab swipe (0 when idle).
    var dragOffset: CGFloat = 0
    /// Number of root tabs.
    let count = 2
    /// Page width, kept current by the pager view; used to settle relative to
    /// how far the swipe actually travelled.
    var width: CGFloat = 390

    /// Commits an ended drag RELATIVE to its travel: the page snaps to whichever
    /// tab is nearest at the gesture's predicted resting point, so a half-screen
    /// swipe switches and a small nudge springs back — momentum included.
    /// - Parameter predicted: the gesture's predicted end translation width.
    func settle(predicted: CGFloat) {
        let projected = CGFloat(selection) - predicted / max(width, 1)
        let target = Int(projected.rounded())
        withAnimation(.snappy(duration: 0.32, extraBounce: 0)) {
            selection = min(count - 1, max(0, target))
            dragOffset = 0
        }
    }
}

/// Finger-tracking tab swipe for root screens: locks to horizontal drags and
/// streams the translation into the shared `TabPager`.
private struct TabSwipeModifier: ViewModifier {
    @Environment(TabPager.self) private var pager: TabPager?
    /// nil until the drag's direction is decided; true = horizontal (ours).
    @State private var isHorizontal: Bool?

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 15)
                .onChanged { value in
                    guard let pager else { return }
                    if isHorizontal == nil {
                        isHorizontal = abs(value.translation.width) > abs(value.translation.height) * 1.2
                    }
                    guard isHorizontal == true else { return }
                    pager.dragOffset = value.translation.width
                }
                .onEnded { value in
                    defer { isHorizontal = nil }
                    guard let pager, isHorizontal == true else { return }
                    pager.settle(predicted: value.predictedEndTranslation.width)
                }
        )
    }
}

extension View {
    /// Horizontal swipe anywhere on a tab's ROOT screen to switch root tabs,
    /// tracking the finger live (no-op when no `TabPager` is in the environment).
    func tabSwipe() -> some View {
        modifier(TabSwipeModifier())
    }

    /// Right-swipe to go back on pushed screens whose system nav bar (and with
    /// it the edge-swipe-back gesture) is hidden for custom chrome.
    func swipeToGoBack(_ action: @escaping () -> Void) -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: 25)
                .onEnded { value in
                    guard value.translation.width > 60,
                          value.translation.width > abs(value.translation.height) * 2 else { return }
                    action()
                }
        )
    }
}

/// A 40pt glass-circle icon button, identical to the spending screen's top-bar
/// buttons, so every screen's chrome buttons are the same size.
struct GlassCircleButton: View {
    /// SF Symbol shown in the circle.
    let systemImage: String
    /// Accessibility label describing the action.
    let label: String
    /// Icon font; the spending screen uses subheadline for glyphs, headline for "+".
    var font: Font = .subheadline.weight(.semibold)
    /// Tap action (haptic included).
    let action: () -> Void

    var body: some View {
        let button = Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(font)
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
        }
        .tint(.primary)
        .accessibilityLabel(label)

        if #available(iOS 26.0, *) {
            button.glassEffect(.regular.interactive(), in: .circle)
        } else {
            button.background(Circle().fill(.thinMaterial))
        }
    }
}

/// Bare monochrome X used in place of text "Cancel" toolbar buttons app-wide.
struct CloseToolbarButton: View {
    /// Dismiss (or other cancel) action to run on tap.
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .accessibilityLabel("Close")
    }
}
