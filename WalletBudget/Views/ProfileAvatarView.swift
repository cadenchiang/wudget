import PhotosUI
import SwiftUI

/// Tappable profile photo: opens the native photo picker (out-of-process, so no
/// photo-library permission prompt) and persists the choice via `ProfileAvatarStore`.
/// Long-press offers photo removal.
struct ProfileAvatarView: View {
    let store: ProfileAvatarStore
    /// Display name used for the initials fallback when no photo is set.
    let name: String?
    @State private var selection: PhotosPickerItem?
    @State private var loadFailed = false

    var body: some View {
        PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
            avatar
        }
        .buttonStyle(.plain)
        .contextMenu {
            if store.image != nil {
                Button("Remove Photo", role: .destructive) {
                    Haptics.tap()
                    store.clear()
                }
            }
        }
        .onChange(of: selection) { _, item in
            guard let item else { return }
            Task { await apply(item) }
        }
        .alert("Couldn't use that photo", isPresented: $loadFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please pick a different photo.")
        }
    }

    /// The avatar circle: the stored photo, or the neutral placeholder, with a
    /// small edit badge so the affordance is discoverable.
    private var avatar: some View {
        ZStack(alignment: .bottomTrailing) {
            ProfileAvatarCircle(image: store.image, name: name)

            Image(systemName: "pencil")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(5)
                .background(Circle().fill(.gray))
                .overlay(Circle().strokeBorder(Color(.systemBackground), lineWidth: 2))
        }
        .accessibilityLabel("Edit profile photo")
    }

    /// Up-to-two-letter initials from a display name ("Caden Chiang" → "CC"),
    /// nil when the name is missing or has no letters.
    /// - Parameter name: the display name.
    /// - Returns: uppercased initials, or nil to fall back to the generic icon.
    nonisolated static func initials(from name: String?) -> String? {
        guard let name else { return nil }
        let letters = name
            .split(whereSeparator: { $0.isWhitespace })
            .prefix(2)
            .compactMap { $0.first(where: \.isLetter) }
        guard !letters.isEmpty else { return nil }
        return String(letters).uppercased()
    }

    /// System palette used for the no-photo avatar background (Contacts-style).
    nonisolated static let fallbackPalette: [Color] = [
        .red, .orange, .green, .teal, .cyan, .blue, .indigo, .purple, .pink,
    ]

    /// Deterministic "random" color for a seed string. Uses djb2 over UTF-8 (NOT
    /// `hashValue`, which is re-seeded every launch and would re-roll the color).
    /// - Parameter seed: usually the display name.
    /// - Returns: a stable color from the system palette.
    nonisolated static func fallbackColor(for seed: String) -> Color {
        var hash = 5381
        for byte in seed.utf8 { hash = (hash &* 33) &+ Int(byte) }
        return fallbackPalette[abs(hash) % fallbackPalette.count]
    }

    /// Loads picked data off the picker item and stores it; failures surface an alert.
    private func apply(_ item: PhotosPickerItem) async {
        defer { selection = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                Log.ui.error("Photo picker returned no data for selected item")
                loadFailed = true
                return
            }
            try store.set(imageData: data)
            Haptics.success()
        } catch {
            Log.ui.error("Avatar load failed: \(error.localizedDescription, privacy: .public)")
            loadFailed = true
        }
    }
}

/// The avatar circle itself — photo, initials, or generic placeholder — at any
/// size. Shared by the editable profile picker above and the read-only settings
/// row, so the avatar always looks identical everywhere it appears.
struct ProfileAvatarCircle: View {
    /// The stored profile photo; nil falls back to initials, then the glyph.
    let image: UIImage?
    /// Display name used for the initials fallback.
    let name: String?
    /// Circle size in points.
    var diameter: CGFloat = 64

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let initials = ProfileAvatarView.initials(from: name) {
                Circle()
                    .fill(ProfileAvatarView.fallbackColor(for: name ?? "").gradient)
                    .overlay {
                        Text(initials)
                            .font(.system(size: diameter * 0.375, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(.gray)
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
    }
}
