import SwiftUI

/// Pins top chrome above a scroll view using the best API for the runtime.
///
/// On iOS 26+, `.safeAreaBar(edge: .top)` gives the system progressive blur (the same scroll
/// edge effect as the tab bar): content scrolls under the bar and blurs away, and the effect
/// extends to the very top edge. On older iOS it falls back to `.safeAreaInset(edge: .top)`
/// with a `.regularMaterial` background that bleeds past the top safe area. The same `bar`
/// closure renders on both paths so behavior stays consistent.
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
                    .background(.regularMaterial, ignoresSafeAreaEdges: .top)
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
