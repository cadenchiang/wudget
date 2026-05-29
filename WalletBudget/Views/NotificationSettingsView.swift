import SwiftUI
import UIKit

/// Settings for the on-device notification system: a master switch, per-type toggles, and the
/// options each type needs (reminder lead time, large-purchase threshold). Changing anything
/// reschedules the notifications immediately.
struct NotificationSettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @State private var notifier = NotificationManager.shared

    @AppStorage(NotificationKeys.enabled) private var enabled = false
    @AppStorage(NotificationKeys.upcomingCharges) private var upcomingCharges = true
    @AppStorage(NotificationKeys.leadDays) private var leadDays = 1
    @AppStorage(NotificationKeys.budgetAlerts) private var budgetAlerts = true
    @AppStorage(NotificationKeys.weeklySummary) private var weeklySummary = true
    @AppStorage(NotificationKeys.monthlyReset) private var monthlyReset = true
    @AppStorage(NotificationKeys.savingsReminder) private var savingsReminder = true
    @AppStorage(NotificationKeys.subscriptionReview) private var subscriptionReview = true
    @AppStorage(NotificationKeys.largePurchase) private var largePurchase = true
    @AppStorage(NotificationKeys.largePurchaseThreshold) private var largeThreshold = 100.0

    /// Whether the system has denied notification permission (so toggles can't take effect).
    private var permissionDenied: Bool { notifier.authorization == .denied }

    /// Selectable "large purchase" thresholds.
    private let thresholds: [Double] = [50, 100, 200, 500]

    var body: some View {
        List {
            masterSection
            if permissionDenied { permissionSection }
            if enabled {
                remindersSection
                budgetSection
                activitySection
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { notifier.refreshAuthorization() }
        .onChange(of: leadDays) { _, _ in reschedule() }
        .onChange(of: largeThreshold) { _, _ in reschedule() }
    }

    private var masterSection: some View {
        Section {
            Toggle("Allow Notifications", isOn: $enabled)
                .onChange(of: enabled) { _, on in handleMasterToggle(on) }
        } footer: {
            Text("All notifications are sent on your device. Nothing leaves your phone.")
        }
    }

    private var permissionSection: some View {
        Section {
            Button("Open Settings to Enable") { openSystemSettings() }
        } footer: {
            Text("Notifications are turned off for WalletBudget in iOS Settings.")
        }
    }

    private var remindersSection: some View {
        Section("Reminders") {
            toggle("Upcoming Charge Reminders", $upcomingCharges)
            if upcomingCharges {
                Picker("Remind Me", selection: $leadDays) {
                    Text("On the day").tag(0)
                    Text("1 day before").tag(1)
                    Text("2 days before").tag(2)
                    Text("3 days before").tag(3)
                }
            }
            toggle("Subscription Review", $subscriptionReview)
        }
    }

    private var budgetSection: some View {
        Section("Budget") {
            toggle("Budget Alerts (80% & 100%)", $budgetAlerts)
            toggle("Monthly Budget Reset", $monthlyReset)
            toggle("Savings Goal Nudge", $savingsReminder)
        }
    }

    private var activitySection: some View {
        Section {
            toggle("Weekly Summary", $weeklySummary)
            toggle("Large Purchase Alerts", $largePurchase)
            if largePurchase {
                Picker("Large Purchase Over", selection: $largeThreshold) {
                    ForEach(thresholds, id: \.self) { amount in
                        Text(amount.asCurrency()).tag(amount)
                    }
                }
            }
        } header: {
            Text("Activity")
        } footer: {
            Text("Get a heads-up before charges, budget check-ins, and alerts for unusually large purchases.")
        }
    }

    /// A toggle bound to a preference that reschedules notifications when changed.
    private func toggle(_ title: String, _ binding: Binding<Bool>) -> some View {
        Toggle(title, isOn: binding)
            .onChange(of: binding.wrappedValue) { _, _ in reschedule() }
    }

    /// Requests permission when enabling (and reschedules); reschedules to clear when disabling.
    private func handleMasterToggle(_ on: Bool) {
        Haptics.tap()
        if on {
            notifier.requestAuthorization { granted in
                if !granted { enabled = false }
                reschedule()
            }
        } else {
            reschedule()
        }
    }

    /// Rebuilds the scheduled notifications from the current settings.
    private func reschedule() {
        notifier.refreshAll(context: context)
    }

    /// Opens the app's page in iOS Settings (to re-enable denied permission).
    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }
}
