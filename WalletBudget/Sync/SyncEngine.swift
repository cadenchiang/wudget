import Foundation
import SwiftData
import Supabase

/// Cloud sync between the on-device SwiftData store and Supabase Postgres.
///
/// SwiftData stays the offline source of truth; this engine reconciles it with
/// the per-user rows in Supabase (RLS-scoped) so the same account sees the same
/// data on any device. Order per cycle: flush local tombstones → pull + merge
/// (last-write-wins via `SyncMerge`) → push everything local. Personal-finance
/// scale (hundreds of rows) makes full-table push idempotent and cheap.
@MainActor
final class SyncEngine {
    static let shared = SyncEngine()

    /// Pending cross-device deletions, persisted so offline deletes survive relaunch.
    private enum TombstoneKey {
        static let expenses = "sync.tombstones.expenses"
        static let cards = "sync.tombstones.cards"
    }

    /// Local stamp for the prefs row (set when the budget/currency change locally).
    static let prefsStampKey = "sync.prefsUpdatedAt"

    private let client: SupabaseClient
    private var syncTask: Task<Void, Never>?

    /// Bumped whenever local data is wiped or the session ends. In-flight cycles
    /// re-check it after every network await and abort instead of applying rows
    /// fetched under the previous account into a freshly wiped store.
    private var generation = 0

    /// - Parameter client: injectable for tests; defaults to the shared client.
    init(client: SupabaseClient = SupabaseService.client) {
        self.client = client
    }

    // MARK: - Triggers

    /// Schedules a sync soon, coalescing bursts of mutations into one cycle.
    func requestSync() {
        syncTask?.cancel()
        syncTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await self?.performSync()
        }
    }

    /// Cancels pending and in-flight sync work. Called before local data is wiped
    /// (account switch/deletion) and on sign-out, so no stale cycle can write
    /// another account's rows into the store.
    func cancelAll() {
        syncTask?.cancel()
        syncTask = nil
        generation += 1
        Log.sync.notice("Sync cancelled; generation bumped")
    }

    /// Deletes an expense locally and queues the tombstone for the cloud.
    func delete(_ expense: Expense, context: ModelContext) {
        enqueueTombstone(expense.id, key: TombstoneKey.expenses)
        context.delete(expense)
        saveQuietly(context, what: "expense delete")
        requestSync()
    }

    /// Deletes a card locally and queues the tombstone for the cloud.
    func delete(_ card: UserCard, context: ModelContext) {
        enqueueTombstone(card.id, key: TombstoneKey.cards)
        context.delete(card)
        saveQuietly(context, what: "card delete")
        requestSync()
    }

    /// Marks the prefs row dirty (budget/currency changed locally) and syncs.
    func prefsChanged() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.prefsStampKey)
        requestSync()
    }

    // MARK: - Sync cycle

    /// One full reconcile pass. Silently no-ops when signed out; all failures are
    /// logged and left for the next cycle (local data is never at risk). The
    /// generation captured at the start guards every phase: if a wipe/sign-out
    /// happens mid-cycle, the remainder aborts cleanly.
    func performSync() async {
        guard let userId = client.auth.currentSession?.user.id else {
            Log.sync.debug("Sync skipped: no session")
            return
        }
        let gen = generation
        let context = SharedModelContainer.container.mainContext
        do {
            try await flushTombstones()
            try checkCurrent(gen)
            try await pullExpenses(userId: userId, context: context, gen: gen)
            try await pullCards(userId: userId, context: context, gen: gen)
            try await syncPrefs(userId: userId, gen: gen)
            try checkCurrent(gen)
            try await pushAll(userId: userId, context: context)
            WidgetUpdater.refresh(context: context)
            Log.sync.info("Sync cycle completed")
        } catch is CancellationError {
            Log.sync.notice("Sync cycle aborted: account state changed mid-cycle")
        } catch {
            Log.sync.error("Sync cycle failed (will retry next trigger): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Throws when the cycle's generation is stale (data wiped / session ended).
    private func checkCurrent(_ gen: Int) throws {
        guard gen == generation else { throw CancellationError() }
    }

    // MARK: - Tombstones

    private func enqueueTombstone(_ id: UUID, key: String) {
        var ids = UserDefaults.standard.stringArray(forKey: key) ?? []
        ids.append(id.uuidString)
        UserDefaults.standard.set(ids, forKey: key)
    }

    /// Pending tombstone ids for merge-time resurrection protection.
    private func pendingTombstones(key: String) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    /// Marks queued deletions on the server (update-only: a row that never
    /// reached the server needs no tombstone), then clears the queue.
    private func flushTombstones() async throws {
        for (key, table) in [(TombstoneKey.expenses, "expenses"), (TombstoneKey.cards, "user_cards")] {
            let ids = UserDefaults.standard.stringArray(forKey: key) ?? []
            guard !ids.isEmpty else { continue }
            try await client.from(table)
                .update(["deleted": AnyJSON.bool(true)])
                .in("id", values: ids)
                .execute()
            UserDefaults.standard.removeObject(forKey: key)
            Log.sync.info("Flushed \(ids.count) tombstones to \(table, privacy: .public)")
        }
    }

    // MARK: - Pull + merge

    private func pullExpenses(userId: UUID, context: ModelContext, gen: Int) async throws {
        let remote: [ExpenseDTO] = try await client.from("expenses")
            .select().eq("user_id", value: userId).execute().value
        try checkCurrent(gen)
        let local = try context.fetch(FetchDescriptor<Expense>())
        let localByID = Dictionary(local.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let pending = pendingTombstones(key: TombstoneKey.expenses)

        for row in remote {
            let action = SyncMerge.action(
                remoteDeleted: row.deleted,
                remoteUpdatedAt: row.updatedAt,
                localUpdatedAt: localByID[row.id]?.updatedAt,
                pendingLocalDelete: pending.contains(row.id.uuidString)
            )
            switch action {
            case .deleteLocal: if let hit = localByID[row.id] { context.delete(hit) }
            case .insertLocal: context.insert(row.makeExpense())
            case .applyRemote: row.apply(to: localByID[row.id]!)
            case .keepLocal, .ignore: break
            }
        }
        saveQuietly(context, what: "expense merge")
    }

    private func pullCards(userId: UUID, context: ModelContext, gen: Int) async throws {
        let remote: [UserCardDTO] = try await client.from("user_cards")
            .select().eq("user_id", value: userId).execute().value
        try checkCurrent(gen)
        let local = try context.fetch(FetchDescriptor<UserCard>())
        let localByID = Dictionary(local.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let pending = pendingTombstones(key: TombstoneKey.cards)

        for row in remote {
            let action = SyncMerge.action(
                remoteDeleted: row.deleted,
                remoteUpdatedAt: row.updatedAt,
                localUpdatedAt: localByID[row.id]?.updatedAt,
                pendingLocalDelete: pending.contains(row.id.uuidString)
            )
            switch action {
            case .deleteLocal: if let hit = localByID[row.id] { context.delete(hit) }
            case .insertLocal: context.insert(row.makeCard())
            case .applyRemote: row.apply(to: localByID[row.id]!)
            case .keepLocal, .ignore: break
            }
        }
        saveQuietly(context, what: "card merge")
    }

    // MARK: - Prefs

    /// Two-way LWW for the single prefs row (budget, variable default, currency).
    private func syncPrefs(userId: UUID, gen: Int) async throws {
        let defaults = UserDefaults.standard
        let localStamp = defaults.double(forKey: Self.prefsStampKey)
        let remote: [UserPrefsDTO] = try await client.from("user_prefs")
            .select().eq("user_id", value: userId).execute().value
        try checkCurrent(gen)

        if let row = remote.first, row.updatedAt.timeIntervalSince1970 > localStamp {
            defaults.set(row.monthlyBudget, forKey: ProfileKeys.monthlyBudget)
            defaults.set(row.variableDefault, forKey: ProfileKeys.variableDefault)
            defaults.set(row.currencyCode, forKey: ProfileKeys.currencyCode)
            defaults.set(row.updatedAt.timeIntervalSince1970, forKey: Self.prefsStampKey)
            Log.sync.info("Prefs pulled from cloud")
        } else if localStamp > 0 {
            let push = UserPrefsDTO(
                userId: userId,
                monthlyBudget: defaults.double(forKey: ProfileKeys.monthlyBudget),
                variableDefault: defaults.bool(forKey: ProfileKeys.variableDefault),
                currencyCode: defaults.string(forKey: ProfileKeys.currencyCode) ?? "USD",
                updatedAt: Date(timeIntervalSince1970: localStamp)
            )
            try await client.from("user_prefs").upsert(push).execute()
        }
    }

    // MARK: - Push

    /// Upserts every local row. Runs after merge, so local state is the freshest
    /// of both sides and a blanket upsert is the correct LWW outcome.
    private func pushAll(userId: UUID, context: ModelContext) async throws {
        let expenses = try context.fetch(FetchDescriptor<Expense>())
            .map { ExpenseDTO(expense: $0, userId: userId) }
        if !expenses.isEmpty {
            try await client.from("expenses").upsert(expenses).execute()
        }
        let cards = try context.fetch(FetchDescriptor<UserCard>())
            .map { UserCardDTO(card: $0, userId: userId) }
        if !cards.isEmpty {
            try await client.from("user_cards").upsert(cards).execute()
        }
        Log.sync.info("Pushed \(expenses.count) expenses, \(cards.count) cards")
    }

    // MARK: - Helpers

    /// Saves the context, logging instead of throwing: a failed save keeps prior
    /// state which the next sync cycle reconciles again.
    private func saveQuietly(_ context: ModelContext, what: String) {
        do { try context.save() } catch {
            Log.sync.error("Context save failed after \(what, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
