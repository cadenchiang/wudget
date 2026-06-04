import SwiftUI
import UIKit

/// Settings for the on-device notification system: a master switch, clearly-described per-type
/// toggles grouped by topic, the options each needs, and a "Send Test Notification" button.
/// Changing anything reschedules the notifications immediately.
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
                billsSection
                budgetSection
                activitySection
                testSection
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
            Text("Notifications are turned off for Budget in iOS Settings.")
        }
    }

    private var billsSection: some View {
        Section("Bills & subscriptions") {
            toggle("Upcoming charge reminders",
                   "Before a recurring charge hits, e.g. “Netflix will charge $15.98 tomorrow.”",
                   $upcomingCharges)
            if upcomingCharges {
                Picker("Remind me", selection: $leadDays) {
                    Text("On the day").tag(0)
                    Text("1 day before").tag(1)
                    Text("2 days before").tag(2)
                    Text("3 days before").tag(3)
                }
            }
            toggle("Monthly subscription review",
                   "On the 1st, a recap of your recurring payments and their total.",
                   $subscriptionReview)
        }
    }

    private var budgetSection: some View {
        Section("Budget") {
            toggle("Budget warnings",
                   "When you reach 80% and 100% of your monthly budget.",
                   $budgetAlerts)
            toggle("New month reminder",
                   "On the 1st, that your budget has reset for the month.",
                   $monthlyReset)
            toggle("Savings goal reminder",
                   "Monthly nudge with how much to set aside for your goal.",
                   $savingsReminder)
        }
    }

    private var activitySection: some View {
        Section("Activity") {
            toggle("Weekly spending recap",
                   "Every Monday, what you spent over the last 7 days.",
                   $weeklySummary)
            toggle("Large purchase alerts",
                   "When a single purchase is over your chosen amount.",
                   $largePurchase)
            if largePurchase {
                Picker("Alert when over", selection: $largeThreshold) {
                    ForEach(thresholds, id: \.self) { amount in
                        Text(amount.asCurrencyRounded()).tag(amount)
                    }
                }
            }
        }
    }

    private var testSection: some View {
        Section {
            Button {
                sendTest()
            } label: {
                Label("Send Test Notification", systemImage: "bell.badge")
            }
        } footer: {
            Text("Sends a sample notification now so you can see how alerts look.")
        }
    }

    /// A toggle with a title and an explanatory caption; reschedules when changed.
    private func toggle(_ title: String, _ description: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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

    /// Requests permission if needed, then delivers a sample notification.
    private func sendTest() {
        Haptics.tap()
        notifier.requestAuthorization { granted in
            if granted { notifier.sendTestNotification() }
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
