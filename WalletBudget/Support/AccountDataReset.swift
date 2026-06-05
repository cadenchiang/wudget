import Foundation
import SwiftData
import UserNotifications
import WidgetKit

/// Wipes account-scoped local state so one user's financial data never leaks to
/// the next account on the same device.
///
/// Called when a DIFFERENT Supabase user signs in than the one who owned the
/// on-device data, and when the account is deleted. Plain sign-out keeps the
/// database (the same user usually returns) but clears the widget and pending
/// notifications, since those surface data while no one is signed in.
@MainActor
enum AccountDataReset {
    /// Remembers which Supabase user id the on-device data belongs to.
    static let ownerKey = "account.ownerUserID"

    /// UserDefaults key prefixes that hold account-scoped state.
    private static let scopedPrefixes = [
        "profile.", "budget.", "spending.", "onboarding.", "notify.",
        "lock.", "location.", "charge.", "sync.",
    ]

    /// Individual account-scoped keys outside the prefixed families.
    private static let scopedKeys = ["walletImportReceived"]

    /// Records the signed-in user as the owner of the on-device data.
    static func recordOwner(userID: String) {
        UserDefaults.standard.set(userID, forKey: ownerKey)
    }

    /// True when on-device data exists for a different user than the one signing in.
    static func isDifferentOwner(than userID: String) -> Bool {
        guard let owner = UserDefaults.standard.string(forKey: ownerKey) else { return false }
        return owner != userID
    }

    /// Full wipe: database, preferences, widget, avatar, notifications, owner stamp.
    ///
    /// Cancels sync first so no in-flight cycle can apply the previous account's
    /// rows into the freshly wiped store. Known accepted limitation: tombstones
    /// queued offline by the previous user are discarded here (they cannot be
    /// flushed without that user's session), so a deletion made offline right
    /// before an account switch may reappear on the original user's other devices.
    static func wipeAllLocalData() {
        SyncEngine.shared.cancelAll()
        wipeDatabase()
        wipeDefaults()
        clearSignedOutSurfaces()
        ProfileAvatarStore().clear()
        UserDefaults.standard.removeObject(forKey: ownerKey)
        Log.store.notice("Account-scoped local data wiped (account switch or deletion)")
    }

    /// Clears the surfaces that keep showing data after sign-out: the home-screen
    /// widget snapshot and every pending/delivered notification.
    static func clearSignedOutSurfaces() {
        WidgetStore.save(.empty)
        WidgetCenter.shared.reloadAllTimelines()
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        Log.store.info("Widget snapshot and notifications cleared")
    }

    /// Deletes every SwiftData model. Categories reseed on next RootView appearance
    /// (CategorySeeder runs in RootView.task), so an empty store is safe.
    private static func wipeDatabase() {
        let context = SharedModelContainer.container.mainContext
        do {
            try context.delete(model: Expense.self)
            try context.delete(model: UserCard.self)
            try context.delete(model: SpendingCategory.self)
            try context.save()
        } catch {
            // Unrecoverable mid-wipe failures must not strand another user's data;
            // log loudly so it surfaces in Console during review/testing.
            Log.store.critical("Local database wipe FAILED: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Removes all account-scoped UserDefaults (profile, budget, onboarding flags,
    /// notification prefs, app lock, location tagging). Device-level preferences
    /// (theme, haptics) survive intentionally.
    private static func wipeDefaults() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys
        where scopedPrefixes.contains(where: key.hasPrefix) || scopedKeys.contains(key) {
            defaults.removeObject(forKey: key)
        }
    }
}
