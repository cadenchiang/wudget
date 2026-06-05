import XCTest
@testable import WalletBudget

/// Unit tests for the cloud-sync logic: merge decisions and DTO round-trips.
final class SyncLogicTests: XCTestCase {
    private let earlier = Date(timeIntervalSince1970: 1_000)
    private let later = Date(timeIntervalSince1970: 2_000)

    // MARK: - Merge decisions

    /// A pending local tombstone always wins: the remote row is ignored so a
    /// just-deleted expense never resurrects mid-sync.
    func testPendingLocalDeleteIgnoresRemote() {
        XCTAssertEqual(
            SyncMerge.action(remoteDeleted: false, remoteUpdatedAt: later,
                             localUpdatedAt: earlier, pendingLocalDelete: true),
            .ignore
        )
    }

    /// Remote tombstones delete the local row.
    func testRemoteTombstoneDeletesLocal() {
        XCTAssertEqual(
            SyncMerge.action(remoteDeleted: true, remoteUpdatedAt: later,
                             localUpdatedAt: earlier, pendingLocalDelete: false),
            .deleteLocal
        )
    }

    /// Rows that only exist remotely are inserted locally.
    func testRemoteOnlyRowInserts() {
        XCTAssertEqual(
            SyncMerge.action(remoteDeleted: false, remoteUpdatedAt: earlier,
                             localUpdatedAt: nil, pendingLocalDelete: false),
            .insertLocal
        )
    }

    /// Strictly newer remote rows overwrite local; ties and older keep local
    /// (which the push phase then propagates).
    func testLastWriteWins() {
        XCTAssertEqual(
            SyncMerge.action(remoteDeleted: false, remoteUpdatedAt: later,
                             localUpdatedAt: earlier, pendingLocalDelete: false),
            .applyRemote
        )
        XCTAssertEqual(
            SyncMerge.action(remoteDeleted: false, remoteUpdatedAt: earlier,
                             localUpdatedAt: later, pendingLocalDelete: false),
            .keepLocal
        )
        XCTAssertEqual(
            SyncMerge.action(remoteDeleted: false, remoteUpdatedAt: earlier,
                             localUpdatedAt: earlier, pendingLocalDelete: false),
            .keepLocal
        )
    }

    // MARK: - Expense DTO round-trip

    /// Local → DTO → local preserves every synced field; location stays behind.
    @MainActor
    func testExpenseDTORoundTrip() {
        let userId = UUID()
        let original = Expense(amount: 12.5, merchant: "Blue Bottle", card: "Apple Card",
                               date: earlier, category: "Coffee", recurrence: .monthly,
                               notes: "latte")
        original.excludedFromBudget = true
        original.viaWalletImport = true
        original.latitude = 37.0
        original.longitude = -122.0
        original.locationName = "Berkeley"
        original.updatedAt = later

        let dto = ExpenseDTO(expense: original, userId: userId)
        XCTAssertEqual(dto.userId, userId)
        XCTAssertFalse(dto.deleted)

        let copy = dto.makeExpense()
        XCTAssertEqual(copy.id, original.id)
        XCTAssertEqual(copy.amount, 12.5)
        XCTAssertEqual(copy.merchant, "Blue Bottle")
        XCTAssertEqual(copy.card, "Apple Card")
        XCTAssertEqual(copy.category, "Coffee")
        XCTAssertEqual(copy.notes, "latte")
        XCTAssertTrue(copy.excludedFromBudget)
        XCTAssertTrue(copy.viaWalletImport)
        XCTAssertEqual(copy.recurrence, .monthly)
        XCTAssertEqual(copy.updatedAt, later)
        // Location never crosses the wire.
        XCTAssertNil(copy.latitude)
        XCTAssertNil(copy.longitude)
        XCTAssertEqual(copy.locationName, "")
    }

    /// Applying a remote DTO onto a local expense keeps the local location.
    @MainActor
    func testApplyRemotePreservesLocalLocation() {
        let local = Expense(amount: 1, merchant: "Old", date: earlier)
        local.latitude = 37.0
        local.locationName = "Berkeley"

        let remoteSource = Expense(amount: 9, merchant: "New", date: later)
        remoteSource.updatedAt = later
        let dto = ExpenseDTO(expense: remoteSource, userId: UUID())
        dto.apply(to: local)

        XCTAssertEqual(local.merchant, "New")
        XCTAssertEqual(local.amount, 9)
        XCTAssertEqual(local.latitude, 37.0, "location must survive remote merges")
        XCTAssertEqual(local.locationName, "Berkeley")
    }

    // MARK: - Card DTO round-trip

    /// Local card → DTO → local card preserves identity and fields.
    @MainActor
    func testCardDTORoundTrip() {
        let card = UserCard(name: "Apple Card", creditLimit: 5_000)
        card.updatedAt = later
        let dto = UserCardDTO(card: card, userId: UUID())
        let copy = dto.makeCard()
        XCTAssertEqual(copy.id, card.id)
        XCTAssertEqual(copy.name, "Apple Card")
        XCTAssertEqual(copy.creditLimit, 5_000)
        XCTAssertEqual(copy.updatedAt, later)
    }

    /// DTO JSON uses the exact snake_case column names of the Postgres schema.
    @MainActor
    func testDTOEncodesSnakeCaseColumns() throws {
        let expense = Expense(amount: 1, merchant: "X", date: earlier)
        let data = try JSONEncoder().encode(ExpenseDTO(expense: expense, userId: UUID()))
        let json = String(data: data, encoding: .utf8)!
        for column in ["user_id", "excluded_from_budget", "via_wallet_import", "updated_at", "deleted"] {
            XCTAssertTrue(json.contains("\"\(column)\""), "missing column \(column)")
        }
    }
}
