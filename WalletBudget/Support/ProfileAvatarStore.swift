import Observation
import UIKit

/// On-device storage for the user's profile photo.
///
/// The image is downscaled and saved as JPEG in Application Support, so it
/// survives launches without touching the network. (Syncing the avatar to the
/// account requires a Supabase Storage bucket; planned alongside expense sync.)
@Observable
@MainActor
final class ProfileAvatarStore {
    /// Errors raised by avatar persistence.
    enum Failure: Error {
        /// The picked data couldn't be decoded as an image.
        case unreadableImage
    }

    /// The current avatar, nil when none has been set.
    private(set) var image: UIImage?

    /// Longest edge of the stored image; avatars render small, so 512 is plenty.
    static let maxDimension: CGFloat = 512

    private let fileURL: URL

    /// - Parameter directory: storage directory override for tests; defaults to
    ///   Application Support (created on first save).
    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0]
        fileURL = base.appendingPathComponent("profile-avatar.jpg")
        image = UIImage(contentsOfFile: fileURL.path)
    }

    /// Downscales and persists a newly picked image, then publishes it.
    /// - Parameter imageData: raw data from the photo picker.
    /// - Throws: `Failure.unreadableImage` for undecodable data, or file-system
    ///   errors from the atomic write.
    func set(imageData: Data) throws {
        guard let jpeg = Self.downscaledJPEGData(from: imageData, maxDimension: Self.maxDimension),
              let decoded = UIImage(data: jpeg) else {
            Log.ui.error("Avatar update failed: picked data is not a decodable image")
            throw Failure.unreadableImage
        }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try jpeg.write(to: fileURL, options: .atomic)
        } catch {
            Log.ui.error("Avatar write failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
        image = decoded
        Log.ui.info("Profile avatar saved (\(jpeg.count) bytes)")
    }

    /// Removes the stored avatar and clears the published image.
    func clear() {
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            // The published image still clears; a stale file only costs disk space.
            Log.ui.error("Avatar file removal failed: \(error.localizedDescription, privacy: .public)")
        }
        image = nil
        Log.ui.info("Profile avatar cleared")
    }

    /// Decodes image data and re-encodes it as JPEG no larger than `maxDimension`
    /// on its longest edge (aspect ratio preserved; never upscales).
    /// - Parameters:
    ///   - data: raw image data.
    ///   - maxDimension: longest allowed edge in points.
    /// - Returns: JPEG data, or nil when the input isn't a decodable image.
    nonisolated static func downscaledJPEGData(from data: Data, maxDimension: CGFloat) -> Data? {
        guard let source = UIImage(data: data) else { return nil }
        let longest = max(source.size.width, source.size.height)
        guard longest > maxDimension else { return source.jpegData(compressionQuality: 0.85) }
        let scale = maxDimension / longest
        let target = CGSize(width: source.size.width * scale, height: source.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target, format: .init(for: .init(displayScale: 1)))
        let resized = renderer.image { _ in source.draw(in: CGRect(origin: .zero, size: target)) }
        return resized.jpegData(compressionQuality: 0.85)
    }
}
