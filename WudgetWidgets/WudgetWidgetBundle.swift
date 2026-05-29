import WidgetKit
import SwiftUI

/// The widget bundle exposed by Wudget's widget extension.
@main
struct WudgetWidgetBundle: WidgetBundle {
    var body: some Widget {
        SpendingWidget()
    }
}
