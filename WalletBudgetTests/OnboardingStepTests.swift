import XCTest
import UIKit
@testable import WalletBudget

/// Unit tests for `OnboardingStep.walletSetup`, the Wallet-automation onboarding sequence.
final class OnboardingStepTests: XCTestCase {
    /// Every step that renders a phone-framed screenshot (no asset logo, no SF Symbol art, not the
    /// live sync-check screen) must have its image present in the asset catalog, otherwise the
    /// user sees the gray placeholder.
    func testAllScreenshotStepsHaveBundledImages() {
        for step in OnboardingStep.walletSetup
        where step.assetImage == nil && step.systemImage == nil && !step.isSyncCheck {
            XCTAssertNotNil(UIImage(named: step.imageName),
                            "Missing asset-catalog image \"\(step.imageName)\" for step \"\(step.title)\"")
        }
    }

    /// The wallet-import wiring screenshots must appear in flow order (walletImport1…9) so the
    /// guide walks the user through the Shortcuts editor sequentially.
    func testWalletImportScreenshotsAreInFlowOrder() {
        let walletImportNames = OnboardingStep.walletSetup
            .map(\.imageName)
            .filter { $0.hasPrefix("walletImport") }
        XCTAssertEqual(walletImportNames, (1...9).map { "walletImport\($0)" })
    }

    /// Each step's image name is unique so no screenshot is accidentally reused.
    func testImageNamesAreUnique() {
        let names = OnboardingStep.walletSetup.map(\.imageName)
        XCTAssertEqual(names.count, Set(names).count, "Duplicate imageName in walletSetup")
    }

    /// Every `tapPoint` must be normalized (0–1) in both axes or the indicator lands off-screen.
    func testTapPointsAreNormalized() {
        for step in OnboardingStep.walletSetup {
            if let point = step.tapPoint {
                XCTAssertTrue((0.0...1.0).contains(point.x) && (0.0...1.0).contains(point.y),
                              "tapPoint \(point) out of unit range for step \"\(step.title)\"")
            }
        }
    }

    /// A `highlight`, when present, must be a substring of the title or it silently never renders.
    func testHighlightsAppearInTitles() {
        for step in OnboardingStep.walletSetup {
            if let highlight = step.highlight {
                XCTAssertNotNil(step.title.range(of: highlight),
                                "Highlight \"\(highlight)\" not found in title \"\(step.title)\"")
            }
        }
    }
}
