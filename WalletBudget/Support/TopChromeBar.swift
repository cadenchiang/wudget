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
