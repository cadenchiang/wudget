import CoreGraphics
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
    /// Optional secondary line shown beneath the title.
    let subtitle: String?
    /// Optional substring of `title` to emphasize (e.g. a button name).
    let highlight: String?
    /// Whether the `highlight` substring is colored blue (true) or left primary (false).
    let highlightColored: Bool
    /// When true, the `highlight` substring renders as a blue pill with white text (a button).
    let highlightPill: Bool
    /// Optional SF Symbol (blue) shown inline just before the highlight.
    let highlightSymbol: String?
    /// When true, the inline symbol replaces the highlight text entirely (icon instead of words).
    let symbolReplacesHighlight: Bool
    /// Optional asset image shown inline just before the highlight.
    let highlightAsset: String?
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
    /// Normalized (0–1) location on the screenshot where a subtle pulsing ring marks the control
    /// to tap. `nil` for confirmation steps with no action.
    let tapPoint: CGPoint?

    init(
        imageName: String,
        title: String,
        subtitle: String? = nil,
        highlight: String? = nil,
        highlightColored: Bool = true,
        highlightPill: Bool = false,
        highlightSymbol: String? = nil,
        symbolReplacesHighlight: Bool = false,
        highlightAsset: String? = nil,
        systemImage: String? = nil,
        assetImage: String? = nil,
        actionTitle: String? = nil,
        actionURLString: String? = nil,
        isSyncCheck: Bool = false,
        tapPoint: CGPoint? = nil
    ) {
        self.imageName = imageName
        self.title = title
        self.subtitle = subtitle
        self.highlight = highlight
        self.highlightColored = highlightColored
        self.highlightPill = highlightPill
        self.highlightSymbol = highlightSymbol
        self.symbolReplacesHighlight = symbolReplacesHighlight
        self.highlightAsset = highlightAsset
        self.systemImage = systemImage
        self.assetImage = assetImage
        self.actionTitle = actionTitle
        self.actionURLString = actionURLString
        self.isSyncCheck = isSyncCheck
        self.tapPoint = tapPoint
    }
}

extension OnboardingStep {
    /// The ordered steps for creating the Wallet transaction automation, split so each
    /// screen covers a single action. `imageName` values correspond to screenshots to be
    /// added to Assets (e.g. "onboarding1"…"onboarding8").
    static let walletSetup: [OnboardingStep] = [
        OnboardingStep(imageName: "onboarding1", title: "Track Apple Pay automatically",
                       subtitle: "This will take about 2 minutes.", assetImage: "applewallet"),
        OnboardingStep(imageName: "onboardingAutomation", title: "Open the Automation tab, then tap New Automation",
                       actionTitle: "Open Shortcuts", actionURLString: "shortcuts://automation",
                       tapPoint: CGPoint(x: 0.50, y: 0.63)),
        OnboardingStep(imageName: "onboarding3", title: "Scroll down and tap Wallet",
                       tapPoint: CGPoint(x: 0.50, y: 0.55)),
        OnboardingStep(imageName: "onboardingCards", title: "Choose your cards, then tap Next",
                       tapPoint: CGPoint(x: 0.87, y: 0.11)),
        OnboardingStep(imageName: "onboardingCreate", title: "Press “Create New Shortcut”",
                       tapPoint: CGPoint(x: 0.25, y: 0.37)),
        // Wiring the "Automatically Log Card Payment" action (screenshots walletImport1…9):
        // add the action, then connect each field (Amount, Merchant, Card) to Shortcut Input.
        OnboardingStep(imageName: "walletImport1", title: "Search Log Card, then tap Automatically Log Card Payment",
                       tapPoint: CGPoint(x: 0.50, y: 0.33)),
        OnboardingStep(imageName: "walletImport2", title: "Tap Amount, then tap Shortcut Input",
                       tapPoint: CGPoint(x: 0.61, y: 0.57)),
        OnboardingStep(imageName: "walletImport3", title: "In the popup, tap Amount",
                       tapPoint: CGPoint(x: 0.50, y: 0.92)),
        OnboardingStep(imageName: "walletImport4", title: "Amount should now be checked"),
        OnboardingStep(imageName: "walletImport5", title: "Tap Merchant, then tap Shortcut Input",
                       tapPoint: CGPoint(x: 0.61, y: 0.57)),
        OnboardingStep(imageName: "walletImport6", title: "In the popup, tap Merchant",
                       tapPoint: CGPoint(x: 0.50, y: 0.87)),
        OnboardingStep(imageName: "walletImport7", title: "Tap Card, then tap Shortcut Input",
                       tapPoint: CGPoint(x: 0.61, y: 0.57)),
        OnboardingStep(imageName: "walletImport8", title: "In the popup, tap Card or Pass",
                       tapPoint: CGPoint(x: 0.50, y: 0.81)),
        OnboardingStep(imageName: "onboardingFinish", title: "Tap the blue checkmark to finish",
                       highlight: "blue checkmark", highlightSymbol: "checkmark.circle.fill",
                       symbolReplacesHighlight: true,
                       tapPoint: CGPoint(x: 0.905, y: 0.114)),
        OnboardingStep(imageName: "walletImport9", title: "This is what it should look like"),
        OnboardingStep(imageName: "onboarding8", title: "Apple Wallet sync", isSyncCheck: true),
    ]
}
