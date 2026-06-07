import SwiftUI
import UIKit

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

    /// Declares the floating root tab bar's zone as bottom chrome, so scroll
    /// content gets the native iOS 26 soft scroll-edge effect (progressive
    /// blur) at the bottom of the screen, exactly like under a system tab bar.
    /// The bar itself is rendered by `RootView`; this clear stand-in only
    /// teaches the scroll view where the bar is. Pre-iOS 26 (no edge effects)
    /// it falls back to a plain inset so content still clears the bar.
    ///
    /// The stand-in is taller than the floating tab pill (≈56pt) on purpose:
    /// the soft scroll-edge blur fills this region, so a region the same size
    /// as the pill would hide the entire blur behind the glass. The extra
    /// height lifts the blur above the pill, making it as visible as the top.
    @ViewBuilder
    func bottomBarScrollEdge() -> some View {
        // Tall enough to clear the floating tab pill and still show blur above it.
        let standInHeight: CGFloat = 100
        if #available(iOS 26.0, *) {
            self
                .safeAreaBar(edge: .bottom, spacing: 0) {
                    Color.clear.frame(height: standInHeight)
                }
                .scrollEdgeEffectStyle(.soft, for: .bottom)
        } else {
            safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: standInHeight)
            }
        }
    }
}

extension View {
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

/// Restores the system interactive pop — the edge swipe-back that LIVE-tracks
/// the finger — on navigation stacks whose bar is hidden for custom chrome
/// (My Cards, Repeat, the spending root). Hiding the navigation bar normally
/// disables this gesture; handing its delegate to the controller re-arms it.
/// The anywhere-on-screen `swipeToGoBack` remains as a complement.
extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    /// Only begin when there is something to pop (never fights the root).
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }

    /// Every pan in the hierarchy (most importantly the root pager's) must
    /// WAIT for the edge-swipe-back to fail before it may begin. With a
    /// sub-page pushed, an edge swipe therefore always pops back — it can
    /// never drag the pager over to the other tab. With nothing pushed the
    /// pop gesture refuses to begin (above), so the pager pans normally.
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        otherGestureRecognizer is UIPanGestureRecognizer
    }
}
