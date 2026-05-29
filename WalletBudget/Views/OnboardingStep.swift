import Foundation

/// One screen of the Wallet-setup onboarding flow.
///
/// Each step is a single screenshot (added to the asset catalog as `imageName`) plus one
/// short line of text. Keep each step to a single action so no screen is text-heavy.
struct OnboardingStep: Identifiable {
    let id = UUID()
    /// Asset-catalog image name for the screenshot shown on this step.
    let imageName: String
    /// One short line shown beneath the screenshot.
    let title: String
    /// Optional SF Symbol shown instead of a screenshot.
    let systemImage: String?
    /// Optional asset-catalog image (e.g. the Apple Wallet logo) shown as an app-icon-style logo.
    let assetImage: String?
    /// Optional action button title (e.g. "Open Shortcuts").
    let actionTitle: String?
    /// Optional URL the action button opens (e.g. "shortcuts://").
    let actionURLString: String?
    /// When true, this step renders the live sync-check screen instead of static art + title.
    let isSyncCheck: Bool

    init(
        imageName: String,
        title: String,
        systemImage: String? = nil,
        assetImage: String? = nil,
        actionTitle: String? = nil,
        actionURLString: String? = nil,
        isSyncCheck: Bool = false
    ) {
        self.imageName = imageName
        self.title = title
        self.systemImage = systemImage
        self.assetImage = assetImage
        self.actionTitle = actionTitle
        self.actionURLString = actionURLString
        self.isSyncCheck = isSyncCheck
    }
}

extension OnboardingStep {
    /// The ordered steps for creating the Wallet transaction automation, split so each
    /// screen covers a single action. `imageName` values correspond to screenshots to be
    /// added to Assets (e.g. "onboarding1"…"onboarding8").
    static let walletSetup: [OnboardingStep] = [
        OnboardingStep(imageName: "onboarding1", title: "Track Apple Pay automatically", assetImage: "applewallet"),
        OnboardingStep(imageName: "onboarding2", title: "Go to the Automation tab",
                       actionTitle: "Open Shortcuts", actionURLString: "shortcuts://"),
        OnboardingStep(imageName: "onboarding3", title: "Tap + and choose the Wallet trigger"),
        OnboardingStep(imageName: "onboarding4", title: "Choose your cards, then tap Next"),
        OnboardingStep(imageName: "onboarding5", title: "Create a new shortcut"),
        OnboardingStep(imageName: "onboarding6", title: "Search “Wallet Import” and add it"),
        OnboardingStep(imageName: "onboarding7", title: "Map Amount, Merchant, and Card"),
        OnboardingStep(imageName: "onboarding8", title: "Apple Wallet sync", isSyncCheck: true),
    ]
}
