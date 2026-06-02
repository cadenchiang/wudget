import SwiftUI
import StoreKit

/// One step in the first-launch personal onboarding. The savings-detail steps are filtered out
/// when the user has no savings goal.
enum PersonalOnboardingStep: String, CaseIterable, Identifiable {
    case birthdate, gender, currency, goals, income, paySchedule
    case budget, variableOnly, savingsPrompt, savingsDetail, savingsDate
    case topCategories, cutbackCategories, subscriptions
    case referral, triedOther, rating, summary
    var id: String { rawValue }
}

/// Renders the input(s) for a single onboarding step, bound to the shared `OnboardingProfile`.
struct PersonalOnboardingStepView: View {
    @Bindable var profile: OnboardingProfile
    let step: PersonalOnboardingStep

    /// Selectable category names (the defaults, minus the catch-all "Other").
    private var categoryNames: [String] {
        CategoryCatalog.defaults.map(\.name).filter { $0 != "Other" }
    }

    private let budgetPresets: [Double] = [500, 1000, 1500, 2000]
    private let birthYears = Array(1940...2012)

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            content
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .birthdate: birthdateStep
        case .gender: genderStep
        case .currency: currencyStep
        case .goals: goalsStep
        case .income: incomeStep
        case .paySchedule: payScheduleStep
        case .budget: budgetStep
        case .variableOnly: variableOnlyStep
        case .savingsPrompt: savingsPromptStep
        case .savingsDetail: savingsDetailStep
        case .savingsDate: savingsDateStep
        case .topCategories: topCategoriesStep
        case .cutbackCategories: cutbackCategoriesStep
        case .subscriptions: subscriptionsStep
        case .referral: referralStep
        case .triedOther: triedOtherStep
        case .rating: RatingStepView(rating: $profile.rating)
        case .summary: summaryStep
        }
    }

    // MARK: - Steps

    private var birthdateStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingHeading(title: "When were you born?", subtitle: birthdateLabel)
            HStack(spacing: 0) {
                Picker("Month", selection: $profile.birthMonth) {
                    ForEach(1...12, id: \.self) { month in
                        Text(Calendar.current.monthSymbols[month - 1]).tag(month)
                    }
                }
                .pickerStyle(.wheel)
                Picker("Day", selection: $profile.birthDay) {
                    ForEach(1...31, id: \.self) { day in
                        Text(verbatim: "\(day)").tag(day)
                    }
                }
                .pickerStyle(.wheel)
                Picker("Year", selection: $profile.birthYear) {
                    ForEach(birthYears, id: \.self) { year in
                        Text(verbatim: "\(year)").tag(year)
                    }
                }
                .pickerStyle(.wheel)
            }
            .frame(height: 170)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.systemGray6)))
        }
    }

    private var genderStep: some View {
        optionStep(title: "Which best describes you?", subtitle: "Helps us tailor insights.") {
            ForEach(Gender.allCases) { gender in
                OnboardingOptionRow(title: gender.rawValue, isSelected: profile.gender == gender) {
                    profile.gender = gender
                }
            }
        }
    }

    private var currencyStep: some View {
        optionStep(title: "Which currency do you use?", subtitle: "Amounts throughout the app use this.") {
            ForEach(OnboardingCurrency.options, id: \.code) { option in
                OnboardingOptionRow(title: option.label, isSelected: profile.currencyCode == option.code) {
                    profile.currencyCode = option.code
                }
            }
        }
    }

    private var goalsStep: some View {
        optionStep(title: "What are your goals?", subtitle: "Pick all that apply.") {
            ForEach(FinancialGoal.allCases) { goal in
                OnboardingOptionRow(title: goal.rawValue, systemImage: goal.icon, isSelected: profile.goals.contains(goal)) {
                    if profile.goals.contains(goal) { profile.goals.remove(goal) } else { profile.goals.insert(goal) }
                }
            }
        }
    }

    private var incomeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingHeading(title: "What's your monthly take-home income?", subtitle: "After taxes. Used to compare against your budget.")
            OnboardingAmountField(placeholder: "0", text: $profile.incomeText)
        }
    }

    private var payScheduleStep: some View {
        optionStep(title: "How often are you paid?") {
            ForEach(PaySchedule.allCases) { schedule in
                OnboardingOptionRow(title: schedule.rawValue, isSelected: profile.paySchedule == schedule) {
                    profile.paySchedule = schedule
                }
            }
        }
    }

    private var budgetStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingHeading(title: "Set your monthly budget", subtitle: budgetSubtitle)
            OnboardingAmountField(placeholder: "0", text: $profile.budgetText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(budgetPresets, id: \.self) { preset in
                        OnboardingChip(label: preset.asCurrencyRounded(), isSelected: profile.budgetValue == preset) {
                            profile.budgetText = String(Int(preset))
                        }
                    }
                }
            }
        }
    }

    /// Shows a "% of income" hint when an income was entered.
    private var budgetSubtitle: String {
        guard profile.incomeValue > 0 else { return "This becomes the target line on your chart." }
        let pct = Int((profile.budgetValue / profile.incomeValue * 100).rounded())
        return profile.budgetValue > 0
            ? "That's \(pct)% of your monthly income."
            : "Tip: many people aim to spend under 80% of income."
    }

    private var variableOnlyStep: some View {
        optionStep(title: "Budget only everyday spending?", subtitle: "Everyday spending excludes fixed costs like rent and wifi, so you focus on what you can change.") {
            OnboardingOptionRow(title: "Yes, ignore fixed costs", isSelected: profile.variableOnly == true) { profile.variableOnly = true }
            OnboardingOptionRow(title: "No, track everything", isSelected: profile.variableOnly == false) { profile.variableOnly = false }
        }
    }

    private var savingsPromptStep: some View {
        optionStep(title: "Do you have a savings goal?") {
            OnboardingOptionRow(title: "Yes, I'm saving for something", isSelected: profile.hasSavingsGoal == true) { profile.hasSavingsGoal = true }
            OnboardingOptionRow(title: "Not right now", isSelected: profile.hasSavingsGoal == false) { profile.hasSavingsGoal = false }
        }
    }

    private var savingsDetailStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingHeading(title: "What are you saving for?")
            TextField("e.g. Emergency fund", text: $profile.savingsName)
                .font(.title3)
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.systemGray6)))
            Text("Target amount").font(.subheadline).foregroundStyle(.secondary)
            OnboardingAmountField(placeholder: "0", text: $profile.savingsAmountText)
        }
    }

    private var savingsDateStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingHeading(title: "By when?", subtitle: savingsPaceSubtitle)
            DatePicker("Target date", selection: $profile.savingsDate, in: Date()..., displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(.black)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.systemGray6)))
        }
    }

    /// "Save about $X/month" pace hint from the target and date.
    private var savingsPaceSubtitle: String {
        let months = max(1, Calendar.current.dateComponents([.month], from: Date(), to: profile.savingsDate).month ?? 1)
        guard profile.savingsValue > 0 else { return "We'll track your progress over time." }
        return "Save about \((profile.savingsValue / Double(months)).asCurrency()) per month to reach it."
    }

    private var topCategoriesStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingHeading(title: "Where do you spend the most?", subtitle: "Pick any. We'll highlight these for you.")
            categoryList(selected: profile.topCategories) { toggle($0, in: \.topCategories) }
        }
    }

    private var cutbackCategoriesStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingHeading(title: "Any you want to cut back on?", subtitle: "Powers future saving tips.")
            categoryList(selected: profile.cutbackCategories) { toggle($0, in: \.cutbackCategories) }
        }
    }

    private var subscriptionsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            OnboardingHeading(title: "Do you have recurring subscriptions?", subtitle: "You can track these in the Repeat section later.")
            OnboardingOptionRow(title: "Yes", isSelected: profile.hasSubscriptions == true) { profile.hasSubscriptions = true }
            OnboardingOptionRow(title: "No", isSelected: profile.hasSubscriptions == false) { profile.hasSubscriptions = false }
            if profile.hasSubscriptions == true {
                Stepper("About \(profile.subscriptionsCount) subscription\(profile.subscriptionsCount == 1 ? "" : "s")",
                        value: $profile.subscriptionsCount, in: 1...50)
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.systemGray6)))
            }
        }
    }

    private var referralStep: some View {
        optionStep(title: "Where did you hear about us?") {
            ForEach(ReferralSource.allCases) { source in
                OnboardingOptionRow(title: source.rawValue, isSelected: profile.referralSource == source) {
                    profile.referralSource = source
                }
            }
        }
    }

    private var triedOtherStep: some View {
        optionStep(title: "Have you tried other budgeting apps?") {
            OnboardingOptionRow(title: "Yes", isSelected: profile.triedOtherApps == true) { profile.triedOtherApps = true }
            OnboardingOptionRow(title: "No", isSelected: profile.triedOtherApps == false) { profile.triedOtherApps = false }
        }
    }

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingHeading(title: profile.name.isEmpty ? "You're all set!" : "You're all set, \(profile.name)!",
                              subtitle: "Here's your starting point. You can change anything later in Settings.")
            VStack(spacing: 0) {
                summaryRow("Monthly budget", profile.budgetValue > 0 ? profile.budgetValue.asCurrency() : "Not set")
                Divider()
                summaryRow("Goals", profile.goals.isEmpty ? "None" : "\(profile.goals.count) selected")
                Divider()
                summaryRow("Saving for", (profile.hasSavingsGoal == true && !profile.savingsName.isEmpty) ? profile.savingsName : "Not set")
                Divider()
                summaryRow("Focus categories", profile.topCategories.isEmpty ? "None" : "\(profile.topCategories.count) selected")
            }
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.systemGray6)))
        }
    }

    // MARK: - Helpers

    /// A heading + a vertical stack of option rows.
    private func optionStep<Rows: View>(title: String, subtitle: String? = nil, @ViewBuilder rows: () -> Rows) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingHeading(title: title, subtitle: subtitle)
            VStack(spacing: 12) { rows() }
        }
    }

    /// A vertical list of category card rows.
    private func categoryList(selected: Set<String>, toggle: @escaping (String) -> Void) -> some View {
        VStack(spacing: 12) {
            ForEach(categoryNames, id: \.self) { name in
                OnboardingCategoryRow(name: name, isSelected: selected.contains(name)) { toggle(name) }
            }
        }
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium).multilineTextAlignment(.trailing)
        }
        .padding(16)
    }

    /// Month name for the current `birthMonth`.
    private var monthName: String {
        let symbols = Calendar.current.monthSymbols
        let index = min(max(profile.birthMonth - 1, 0), symbols.count - 1)
        return symbols[index]
    }

    /// Readable birthdate label ("March 14, 1998").
    private var birthdateLabel: String {
        "\(monthName) \(profile.birthDay), \(profile.birthYear)"
    }

    /// Toggles a category name within one of the profile's selection sets.
    private func toggle(_ name: String, in keyPath: ReferenceWritableKeyPath<OnboardingProfile, Set<String>>) {
        if profile[keyPath: keyPath].contains(name) {
            profile[keyPath: keyPath].remove(name)
        } else {
            profile[keyPath: keyPath].insert(name)
        }
    }
}

/// The rating step: five tappable stars that also trigger the system review prompt on 4-5 stars.
private struct RatingStepView: View {
    @Binding var rating: Int
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingHeading(title: "Enjoying Wudget?", subtitle: "Tap to rate us, it really helps.")
            StarRatingRow(rating: $rating)
                .onChange(of: rating) { _, value in
                    if value >= 4 { requestReview() }
                }
            Spacer(minLength: 0)
        }
    }
}
