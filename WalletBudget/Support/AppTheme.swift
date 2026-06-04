import SwiftUI

/// User-selectable appearance, stored in `@AppStorage(AppTheme.storageKey)` and applied at the
/// app root via `.preferredColorScheme`.
enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// `@AppStorage` / `UserDefaults` key.
    static let storageKey = "appearance"

    /// Label shown in the picker.
    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// The color scheme to force, or `nil` to follow the system setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

extension Color {
    /// The app icon's background blue (RGB 99/191/240), used full-bleed on the welcome landing
    /// and the Face ID lock screen so both blend seamlessly with the icon artwork.
    static let brandBlue = Color(red: 99 / 255, green: 191 / 255, blue: 240 / 255)
}
