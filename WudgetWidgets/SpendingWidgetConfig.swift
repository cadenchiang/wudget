import AppIntents
import WidgetKit

/// What the widget's big number shows. Users pick this in the widget's "Edit Widget" panel.
enum WidgetDisplayMode: String, AppEnum {
    /// The exact dollar amount spent this month (e.g. "$1,679").
    case amount
    /// The share of the monthly budget used so far (e.g. "68%"). More private on a home screen;
    /// falls back to the amount when no budget is set.
    case percent

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Display"
    static var caseDisplayRepresentations: [WidgetDisplayMode: DisplayRepresentation] = [
        .amount: "Dollar amount",
        .percent: "Percent of budget"
    ]
}

/// The widget's user-editable configuration. Adding it (vs a static widget) is what makes the
/// widget show an "Edit Widget" option on long-press.
struct SpendingWidgetConfig: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Spending"
    static var description = IntentDescription("Choose what the Spending widget shows.")

    /// Whether the big number is a dollar amount or a percent of budget.
    @Parameter(title: "Show", default: .amount)
    var displayMode: WidgetDisplayMode
}
