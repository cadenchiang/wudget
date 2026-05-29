import SwiftUI
import UIKit

/// The first-launch personal onboarding: a long, paged questionnaire (name, birthdate, gender,
/// currency, goals, income, budget, savings, spending habits, referral, rating) that configures
/// the app on finish.
///
/// Each step requires an answer before "Continue" enables. The savings-detail steps are skipped
/// when the user has no savings goal. Going back from the first step exits to the welcome landing
/// (`onExit`); finishing commits the profile and hands off via `onComplete`.
struct PersonalOnboardingFlow: View {
    /// Called once the questionnaire finishes (the flow has already committed the profile).
    var onComplete: () -> Void = {}
    /// Called when the user backs out of the first step (returns to the welcome landing).
    var onExit: () -> Void = {}

    @Environment(\.modelContext) private var context
    @AppStorage(ProfileKeys.completed) private var completed = false
    @State private var profile = OnboardingProfile()
    @State private var index = 0

    /// The active, ordered steps (savings detail/date appear only with a savings goal).
    private var steps: [PersonalOnboardingStep] {
        PersonalOnboardingStep.allCases.filter { step in
            if step == .savingsDetail || step == .savingsDate { return profile.hasSavingsGoal == true }
            return true
        }
    }

    private var isLast: Bool { index >= steps.count - 1 }
    private var currentStep: PersonalOnboardingStep { steps[min(index, steps.count - 1)] }

    var body: some View {
        VStack(spacing: 0) {
            header
            TabView(selection: $index) {
                ForEach(Array(steps.enumerated()), id: \.element) { offset, step in
                    ScrollView {
                        PersonalOnboardingStepView(profile: profile, step: step)
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                            .padding(.bottom, 24)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: index)
            footer
        }
        .background(Color(.systemBackground))
    }

    /// Back button (black) + thin black progress bar.
    private var header: some View {
        HStack(spacing: 12) {
            Button(action: back) {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color(.systemGray6)))
            }

            ProgressView(value: Double(index + 1), total: Double(max(steps.count, 1)))
                .tint(.black)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    /// Primary advance/finish button — black, and disabled until the step is answered.
    private var footer: some View {
        Button(action: advance) {
            Text(isLast ? "Get Started" : "Continue")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(.black)
        .disabled(!isStepComplete)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    /// Whether the current step has a valid answer (gates the Continue button).
    private var isStepComplete: Bool {
        switch currentStep {
        case .name: return !profile.name.trimmingCharacters(in: .whitespaces).isEmpty
        case .birthdate, .savingsDate, .summary: return true
        case .savingsDetail: return profile.savingsValue > 0
        case .gender: return profile.gender != nil
        case .currency: return profile.currencyCode != nil
        case .goals: return !profile.goals.isEmpty
        case .income: return profile.incomeValue > 0
        case .paySchedule: return profile.paySchedule != nil
        case .budget: return profile.budgetValue > 0
        case .variableOnly: return profile.variableOnly != nil
        case .savingsPrompt: return profile.hasSavingsGoal != nil
        case .topCategories: return !profile.topCategories.isEmpty
        case .cutbackCategories: return !profile.cutbackCategories.isEmpty
        case .subscriptions: return profile.hasSubscriptions != nil
        case .referral: return profile.referralSource != nil
        case .triedOther: return profile.triedOtherApps != nil
        case .rating: return profile.rating > 0
        }
    }

    /// Advances to the next step, or finishes on the last step. Dismisses the keyboard first so
    /// tapping Continue while typing exits the text field.
    private func advance() {
        dismissKeyboard()
        Haptics.tap()
        if isLast {
            finish()
        } else {
            withAnimation { index = min(index + 1, steps.count - 1) }
        }
    }

    /// Resigns the first responder to dismiss any active keyboard.
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// Goes back one step, or exits to the welcome landing from the first step.
    private func back() {
        Haptics.tap()
        if index == 0 {
            onExit()
        } else {
            withAnimation { index -= 1 }
        }
    }

    /// Persists the profile, configures the app, marks onboarding complete, and hands off.
    private func finish() {
        profile.commit(context: context)
        Haptics.success()
        completed = true
        onComplete()
    }
}
