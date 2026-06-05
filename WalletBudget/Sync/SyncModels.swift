import Foundation

/// Wire representation of an `Expense` row in Supabase.
///
/// Location fields are deliberately absent: purchase locations never leave the
/// device. `deleted` is the cross-device tombstone flag.
struct ExpenseDTO: Codable, Equatable {
    let id: UUID
    let userId: UUID
    let amount: Double
    let merchant: String
    let card: String
    let date: Date
    let category: String
    let notes: String
    let excludedFromBudget: Bool
    let viaWalletImport: Bool
    let recurrence: String
    let deleted: Bool
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case amount, merchant, card, date, category, notes
        case excludedFromBudget = "excluded_from_budget"
        case viaWalletImport = "via_wallet_import"
        case recurrence, deleted
        case updatedAt = "updated_at"
    }

    /// Builds the wire row from a local expense.
    /// - Parameters:
    ///   - expense: the local model.
    ///   - userId: owner (the signed-in Supabase user).
    init(expense: Expense, userId: UUID) {
        self.id = expense.id
        self.userId = userId
        self.amount = expense.amount
        self.merchant = expense.merchant
        self.card = expense.card
        self.date = expense.date
        self.category = expense.category
        self.notes = expense.notes
        self.excludedFromBudget = expense.excludedFromBudget
        self.viaWalletImport = expense.viaWalletImport
        self.recurrence = expense.recurrenceRaw
        self.deleted = false
        self.updatedAt = expense.updatedAt
    }

    /// Copies remote fields onto a local expense (used when the remote row wins).
    /// Location fields are untouched: they exist only locally.
    /// - Parameter expense: the local model to update in place.
    func apply(to expense: Expense) {
        expense.amount = amount
        expense.merchant = merchant
        expense.card = card
        expense.date = date
        expense.category = category
        expense.notes = notes
        expense.excludedFromBudget = excludedFromBudget
        expense.viaWalletImport = viaWalletImport
        expense.recurrenceRaw = recurrence
        expense.updatedAt = updatedAt
    }

    /// Materializes a brand-new local expense from the remote row.
    func makeExpense() -> Expense {
        let expense = Expense(
            id: id, amount: amount, merchant: merchant, card: card,
            date: date, category: category,
            recurrence: RecurrenceFrequency(rawValue: recurrence) ?? .none,
            notes: notes
        )
        expense.excludedFromBudget = excludedFromBudget
        expense.viaWalletImport = viaWalletImport
        expense.updatedAt = updatedAt
        return expense
    }
}

/// Wire representation of a `UserCard` row in Supabase.
struct UserCardDTO: Codable, Equatable {
    let id: UUID
    let userId: UUID
    let name: String
    let creditLimit: Double?
    let createdAt: Date
    let deleted: Bool
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case creditLimit = "credit_limit"
        case createdAt = "created_at"
        case deleted
        case updatedAt = "updated_at"
    }

    /// Builds the wire row from a local card.
    init(card: UserCard, userId: UUID) {
        self.id = card.id
        self.userId = userId
        self.name = card.name
        self.creditLimit = card.creditLimit
        self.createdAt = card.createdAt
        self.deleted = false
        self.updatedAt = card.updatedAt
    }

    /// Copies remote fields onto a local card (remote row wins).
    func apply(to card: UserCard) {
        card.name = name
        card.creditLimit = creditLimit
        card.createdAt = createdAt
        card.updatedAt = updatedAt
    }

    /// Materializes a brand-new local card from the remote row.
    func makeCard() -> UserCard {
        let card = UserCard(name: name, creditLimit: creditLimit)
        card.id = id
        card.createdAt = createdAt
        card.updatedAt = updatedAt
        return card
    }
}

/// Wire representation of the single per-user preferences row.
struct UserPrefsDTO: Codable, Equatable {
    let userId: UUID
    let monthlyBudget: Double
    let variableDefault: Bool
    let currencyCode: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case monthlyBudget = "monthly_budget"
        case variableDefault = "variable_default"
        case currencyCode = "currency_code"
        case updatedAt = "updated_at"
    }
}

/// Pure last-write-wins merge decisions, separated for unit testing.
enum SyncMerge {
    /// What the pull phase should do with one remote row.
    enum Action: Equatable {
        /// Remote tombstone: delete the local row if present.
        case deleteLocal
        /// No local row exists: insert from remote.
        case insertLocal
        /// Remote is strictly newer: overwrite local fields.
        case applyRemote
        /// Local is same-or-newer (it gets pushed afterwards): do nothing.
        case keepLocal
        /// A local tombstone is pending for this id: ignore the remote row.
        case ignore
    }

    /// Decides the merge action for a remote row.
    /// - Parameters:
    ///   - remoteDeleted: remote tombstone flag.
    ///   - remoteUpdatedAt: remote modification time.
    ///   - localUpdatedAt: local modification time, nil when no local row exists.
    ///   - pendingLocalDelete: whether this id is queued for deletion locally.
    static func action(
        remoteDeleted: Bool,
        remoteUpdatedAt: Date,
        localUpdatedAt: Date?,
        pendingLocalDelete: Bool
    ) -> Action {
        if pendingLocalDelete { return .ignore }
        if remoteDeleted { return .deleteLocal }
        guard let localUpdatedAt else { return .insertLocal }
        return remoteUpdatedAt > localUpdatedAt ? .applyRemote : .keepLocal
    }
}
