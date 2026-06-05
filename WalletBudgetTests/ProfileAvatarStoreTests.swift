import UIKit
import XCTest
@testable import WalletBudget

/// Unit tests for `ProfileAvatarStore` (persistence roundtrip and downscaling).
@MainActor
final class ProfileAvatarStoreTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("avatar-tests-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    /// Renders a solid-color test image of the given size as PNG data.
    private func imageData(width: CGFloat, height: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        let image = renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return image.pngData()!
    }

    /// Saving publishes the image and survives a fresh store (disk roundtrip).
    func testSetPersistsAcrossInstances() throws {
        let store = ProfileAvatarStore(directory: tempDir)
        XCTAssertNil(store.image)

        try store.set(imageData: imageData(width: 100, height: 80))
        XCTAssertNotNil(store.image)

        let reloaded = ProfileAvatarStore(directory: tempDir)
        XCTAssertNotNil(reloaded.image, "avatar should reload from disk")
    }

    /// Clearing removes both the published image and the file.
    func testClearRemovesImage() throws {
        let store = ProfileAvatarStore(directory: tempDir)
        try store.set(imageData: imageData(width: 100, height: 80))

        store.clear()
        XCTAssertNil(store.image)
        XCTAssertNil(ProfileAvatarStore(directory: tempDir).image, "file should be gone")
    }

    /// Garbage data raises `unreadableImage` instead of silently failing.
    func testSetRejectsGarbageData() {
        let store = ProfileAvatarStore(directory: tempDir)
        XCTAssertThrowsError(try store.set(imageData: Data("not an image".utf8))) { error in
            XCTAssertTrue(error is ProfileAvatarStore.Failure)
        }
        XCTAssertNil(store.image)
    }

    /// Oversized images shrink to the max dimension with aspect ratio preserved.
    func testDownscaleShrinksLargeImages() {
        let data = ProfileAvatarStore.downscaledJPEGData(
            from: imageData(width: 2048, height: 1024), maxDimension: 512
        )
        let result = UIImage(data: data!)!
        XCTAssertEqual(result.size.width * result.scale, 512, accuracy: 2)
        XCTAssertEqual(result.size.height * result.scale, 256, accuracy: 2)
    }

    /// Images already within bounds are not upscaled.
    func testDownscaleNeverUpscales() {
        let data = ProfileAvatarStore.downscaledJPEGData(
            from: imageData(width: 100, height: 50), maxDimension: 512
        )
        let result = UIImage(data: data!)!
        XCTAssertEqual(result.size.width * result.scale, 100, accuracy: 2)
    }

    /// Non-image input returns nil from the downscaler.
    func testDownscaleRejectsGarbage() {
        XCTAssertNil(ProfileAvatarStore.downscaledJPEGData(from: Data([0x00, 0x01]), maxDimension: 512))
    }

    // MARK: - Fallback avatar helpers

    /// Initials take the first letter of up to two words; no letters means nil.
    func testInitials() {
        XCTAssertEqual(ProfileAvatarView.initials(from: "Caden Chiang"), "CC")
        XCTAssertEqual(ProfileAvatarView.initials(from: "caden"), "C")
        XCTAssertEqual(ProfileAvatarView.initials(from: "Caden J Chiang"), "CJ")
        XCTAssertEqual(ProfileAvatarView.initials(from: "  caden   chiang  "), "CC")
        XCTAssertNil(ProfileAvatarView.initials(from: nil))
        XCTAssertNil(ProfileAvatarView.initials(from: ""))
        XCTAssertNil(ProfileAvatarView.initials(from: "123 456"))
    }

    /// The fallback color is stable for a seed and drawn from the palette.
    func testFallbackColorIsDeterministic() {
        XCTAssertEqual(
            ProfileAvatarView.fallbackColor(for: "Caden Chiang"),
            ProfileAvatarView.fallbackColor(for: "Caden Chiang")
        )
        XCTAssertTrue(ProfileAvatarView.fallbackPalette.contains(ProfileAvatarView.fallbackColor(for: "anything")))
        // Different seeds should usually differ (spot-check two known-distinct seeds).
        XCTAssertNotEqual(
            ProfileAvatarView.fallbackColor(for: "Caden Chiang"),
            ProfileAvatarView.fallbackColor(for: "Ada Lovelace")
        )
    }
}
