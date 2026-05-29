import SwiftUI
import SwiftData

/// Gender collected during onboarding.
enum Gender: String, CaseIterable, Identifiable {
    case male = "Male"
    case female = "Female"
    case nonBinary = "Non-binary"
    case preferNot = "Prefer not to say"
    var id: String { rawValue }
}

/// The user's financial goals (multi-select), used to frame tips.
enum FinancialGoal: String, CaseIterable, Identifiable {
    case payDebt = "Pay off debt"
    case buildSavings = "Build savings"
    case invest = "Invest"
    case budgetBetter = "Budget better"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .payDebt: return "creditcard"
        case .buildSavings: return "banknote"
        case .invest: return "chart.line.uptrend.xyaxis"
        case .budgetBetter: return "chart.pie"
        }
    }
}

/// How often the user is paid.
enum PaySchedule: String, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case biweekly = "Every 2 weeks"
    case semimonthly = "Twice a month"
    case monthly = "Monthly"
    case irregular = "Irregular"
    case notPaid = "I'm not paid"
    var id: String { rawValue }
}

/// Where the user heard about the app.
enum ReferralSource: String, CaseIterable, Identifiable {
    case appStore = "App Store"
    case friend = "Friend or family"
    case social = "Social media"
    case search = "Web search"
    case news = "News or blog"
    case other = "Other"
    var id: String { rawValue }
}

/// Mutable answer holder for the first-launch personal onboarding.
///
/// Optional fields start unselected so nothing is auto-chosen. Amount inputs are kept as text and
/// parsed on `commit`. `commit(context:)` persists everything to `UserDefaults`, configures the
/// app (monthly budget, currency, seeded categories), and marks onboarding complete.
@Observable
final class OnboardingProfile {
    var name = ""
    var birthMonth = 1
    var birthDay = 1
    var birthYear = 2000
    var gender: Gender?
    var currencyCode: String?
    var goals: Set<FinancialGoal> = []
    var incomeText = ""
    var paySchedule: PaySchedule?
    var budgetText = ""
    var variableOnly: Bool?
    var hasSavingsGoal: Bool?
    var savingsName = ""
    var savingsAmountText = ""
    var savingsDate: Date
    var topCategories: Set<String> = []
    var cutbackCategories: Set<String> = []
    var hasSubscriptions: Bool?
    var subscriptionsCount = 1
    var referralSource: ReferralSource?
    var triedOtherApps: Bool?
    var rating = 0

    init() {
        savingsDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    }

    /// Parsed monthly budget (0 when blank/invalid).
    var budgetValue: Double { CurrencyParser.parse(budgetText) ?? 0 }
    /// Parsed monthly income (0 when blank/invalid).
    var incomeValue: Double { CurrencyParser.parse(incomeText) ?? 0 }
    /// Parsed savings target (0 when blank/invalid).
    var savingsValue: Double { CurrencyParser.parse(savingsAmountText) ?? 0 }

    /// Persists all answers, wires them into the app, and marks onboarding complete.
    /// - Parameter context: Model context used to seed default categories.
    @MainActor
    func commit(context: ModelContext) {
        let defaults = UserDefaults.standard
        defaults.set(name.trimmingCharacters(in: .whitespaces), forKey: ProfileKeys.name)
        defaults.set(birthMonth, forKey: ProfileKeys.birthMonth)
        defaults.set(birthDay, forKey: ProfileKeys.birthDay)
        defaults.set(birthYear, forKey: ProfileKeys.birthYear)
        defaults.set(gender?.rawValue ?? "", forKey: ProfileKeys.gender)
        defaults.set(currencyCode ?? (Locale.current.currency?.identifier ?? "USD"), forKey: ProfileKeys.currencyCode)
        defaults.set(goals.map(\.rawValue), forKey: ProfileKeys.goals)
        defaults.set(incomeValue, forKey: ProfileKeys.income)
        defaults.set(paySchedule?.rawValue ?? "", forKey: ProfileKeys.paySchedule)
        defaults.set(budgetValue, forKey: ProfileKeys.monthlyBudget)
        defaults.set(variableOnly ?? false, forKey: ProfileKeys.variableDefault)
        let savingGoal = hasSavingsGoal ?? false
        defaults.set(savingGoal, forKey: ProfileKeys.hasSavingsGoal)
        defaults.set(savingsName.trimmingCharacters(in: .whitespaces), forKey: ProfileKeys.savingsName)
        defaults.set(savingGoal ? savingsValue : 0, forKey: ProfileKeys.savingsAmount)
        defaults.set(savingsDate.timeIntervalSince1970, forKey: ProfileKeys.savingsDate)
        defaults.set(Array(topCategories), forKey: ProfileKeys.topCategories)
        defaults.set(Array(cutbackCategories), forKey: ProfileKeys.cutbackCategories)
        let subs = hasSubscriptions ?? false
        defaults.set(subs, forKey: ProfileKeys.hasSubscriptions)
        defaults.set(subs ? subscriptionsCount : 0, forKey: ProfileKeys.subscriptionsCount)
        defaults.set(referralSource?.rawValue ?? "", forKey: ProfileKeys.referralSource)
        defaults.set(triedOtherApps ?? false, forKey: ProfileKeys.triedOtherApps)
        defaults.set(rating, forKey: ProfileKeys.rating)

        CategorySeeder.seedAndRefresh(context: context)
        defaults.set(true, forKey: ProfileKeys.completed)
        Log.ui.info("Completed personal onboarding (budget \(self.budgetValue))")
    }
}

/// `UserDefaults` keys for the stored profile (and the shared budget/completion flags).
enum ProfileKeys {
    static let name = "profile.name"
    static let birthMonth = "profile.birthMonth"
    static let birthDay = "profile.birthDay"
    static let birthYear = "profile.birthYear"
    static let gender = "profile.gender"
    static let currencyCode = "profile.currencyCode"
    static let goals = "profile.goals"
    static let income = "profile.income"
    static let paySchedule = "profile.paySchedule"
    static let monthlyBudget = "budget.monthly"
    static let variableDefault = "spending.variableDefault"
    static let hasSavingsGoal = "profile.hasSavingsGoal"
    static let savingsName = "profile.savingsName"
    static let savingsAmount = "profile.savingsAmount"
    static let savingsDate = "profile.savingsDate"
    static let topCategories = "profile.topCategories"
    static let cutbackCategories = "profile.cutbackCategories"
    static let hasSubscriptions = "profile.hasSubscriptions"
    static let subscriptionsCount = "profile.subscriptionsCount"
    static let referralSource = "profile.referralSource"
    static let triedOtherApps = "profile.triedOtherApps"
    static let rating = "profile.rating"
    static let completed = "onboarding.personalCompleted"
}
