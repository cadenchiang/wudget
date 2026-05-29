import SwiftUI

/// Large left-aligned title plus an optional subtitle, used at the top of each onboarding step.
struct OnboardingHeading: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title.bold())
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A large full-width selectable option row (radio-style) with an optional leading icon. Selected
/// rows fill black.
struct OnboardingOptionRow: View {
    let title: String
    var systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 14) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .frame(width: 30)
                }
                Text(title)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(isSelected ? .white : .primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.black : Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }
}

/// A pill-shaped multi-select chip. Selected chips fill black.
struct OnboardingChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Text(label)
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    Capsule().fill(isSelected ? Color.black : Color(.systemGray6))
                )
        }
        .buttonStyle(.plain)
    }
}

/// A large card row for selecting a category, matching the app's spending rows: a colored icon
/// tile, the category name, and a checkmark. Selected rows get a black border + filled check.
struct OnboardingCategoryRow: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(CategoryStyle.color(for: name).gradient)
                    .frame(width: 46, height: 46)
                    .overlay {
                        Image(systemName: CategoryStyle.icon(for: name))
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                Text(name)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .black : Color(.tertiaryLabel))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? Color.black : .clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

/// A row of five tappable stars for an in-onboarding rating.
struct StarRatingRow: View {
    @Binding var rating: Int

    var body: some View {
        HStack(spacing: 12) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: 38))
                    .foregroundStyle(star <= rating ? .yellow : Color(.tertiaryLabel))
                    .onTapGesture {
                        Haptics.selection()
                        rating = star
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// A large "$ amount" entry field used for income/budget/savings steps.
struct OnboardingAmountField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Text("$")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .font(.largeTitle.weight(.semibold))
                .keyboardType(.decimalPad)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemGray6))
        )
    }
}

/// A small curated set of common currencies offered during onboarding.
enum OnboardingCurrency {
    /// (code, label) pairs shown in the currency picker.
    static let options: [(code: String, label: String)] = [
        ("USD", "US Dollar ($)"),
        ("EUR", "Euro (€)"),
        ("GBP", "British Pound (£)"),
        ("CAD", "Canadian Dollar ($)"),
        ("AUD", "Australian Dollar ($)"),
        ("JPY", "Japanese Yen (¥)"),
        ("CNY", "Chinese Yuan (¥)"),
        ("INR", "Indian Rupee (₹)"),
        ("MXN", "Mexican Peso ($)"),
        ("BRL", "Brazilian Real (R$)")
    ]

    /// The display label for a currency code, falling back to the code itself.
    static func label(for code: String) -> String {
        options.first { $0.code == code }?.label ?? code
    }
}
