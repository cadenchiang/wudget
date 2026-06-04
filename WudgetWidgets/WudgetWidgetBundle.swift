import WidgetKit
import SwiftUI

/// The widget bundle exposed by Budget's widget extension.
@main
struct WudgetWidgetBundle: WidgetBundle {
    var body: some Widget {
        SpendingWidget()
    }
}
