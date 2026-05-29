import SwiftUI
import UIKit

/// Full-screen, paged onboarding that walks the user through creating the Wallet transaction
/// automation, one screenshot per screen.
///
/// A progress bar at the top tracks position; the bottom button advances and becomes "Done" on
/// the final screen. Users can also swipe between steps. Presented via `.fullScreenCover` from
/// `SetupGuideView`.
struct OnboardingFlow: View {
    @Environment(\.dismiss) private var dismiss

    private let steps = OnboardingStep.walletSetup
    @State private var index = 0

    private var progress: Double {
        Double(index + 1) / Double(steps.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            TabView(selection: $index) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { offset, step in
                    OnboardingStepView(step: step).tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: index)
            footer
        }
    }

    /// Back button on the left, with the progress bar filling the rest of the width.
    private var header: some View {
        HStack(spacing: 14) {
            backButton
            progressBar
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 6)
        .animation(.easeInOut, value: index)
    }

    /// Back chevron on a Liquid Glass circle (material circle fallback pre-iOS 26).
    @ViewBuilder
    private var backButton: some View {
        let button = Button { goBack() } label: {
            Image(systemName: "chevron.left")
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 38, height: 38)
        }
        .tint(.primary)

        if #available(iOS 26.0, *) {
            button.glassEffect(.regular.interactive(), in: .circle)
        } else {
            button.background(Circle().fill(.thinMaterial))
        }
    }

    /// Full-width progress bar (fills the space to the right of the back button).
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.2))
                Capsule().fill(Color.primary).frame(width: geo.size.width * progress)
            }
        }
        .frame(height: 4)
    }

    /// Steps back one screen, or dismisses the flow when already on the first step.
    private func goBack() {
        Haptics.tap()
        if index > 0 {
            withAnimation { index -= 1 }
        } else {
            dismiss()
        }
    }

    /// Primary advance/finish button.
    private var footer: some View {
        Button(action: advance) {
            Text(isLastStep ? "Done" : "Continue")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(isLastStep ? .green : .primary)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private var isLastStep: Bool { index >= steps.count - 1 }

    /// Advances to the next step, or dismisses on the last step.
    private func advance() {
        if isLastStep {
            Haptics.success()
            dismiss()
        } else {
            Haptics.tap()
            withAnimation { index += 1 }
        }
    }
}

/// A single onboarding screen: the Wallet logo or an iPhone-framed screenshot, plus one line of
/// black text and an optional action button.
private struct OnboardingStepView: View {
    let step: OnboardingStep
    @Environment(\.openURL) private var openURL

    var body: some View {
        if step.isSyncCheck {
            SyncCheckView()
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
        } else if step.assetImage != nil {
            logoStep
        } else {
            standardStep
        }
    }

    /// Intro/logo screen: the icon centered with its title directly beneath it.
    private var logoStep: some View {
        VStack(spacing: 20) {
            Spacer()
            artwork
            Text(step.title)
                .font(.title.bold())
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    private var standardStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text(step.title)
                    .font(.title.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let actionTitle = step.actionTitle,
                   let urlString = step.actionURLString,
                   let url = URL(string: urlString) {
                    Button { Haptics.tap(); openURL(url) } label: {
                        HStack(spacing: 4) {
                            Text(actionTitle)
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.purple)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            artwork
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    /// The logo (intro step) or the iPhone-framed screenshot.
    @ViewBuilder
    private var artwork: some View {
        if let asset = step.assetImage {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
        } else if let symbol = step.systemImage {
            Image(systemName: symbol)
                .font(.system(size: 96, weight: .regular))
                .foregroundStyle(.green)
        } else {
            PhoneFrame(imageName: step.imageName)
                .frame(maxHeight: 470)
        }
    }
}

/// Renders a full screenshot inside a simple iPhone frame (black bezel, rounded screen) so users
/// see what the step looks like on their phone. Falls back to a placeholder until the screenshot
/// is added to the asset catalog.
private struct PhoneFrame: View {
    let imageName: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(.black)
            screen
                .clipShape(RoundedRectangle(cornerRadius: 33, style: .continuous))
                .padding(5)
        }
        .overlay(alignment: .top) {
            GeometryReader { geo in
                Capsule()
                    .fill(.black)
                    .frame(width: geo.size.width * 0.30, height: geo.size.width * 0.085)
                    .frame(maxWidth: .infinity)
                    .padding(.top, geo.size.width * 0.05 + 6)
            }
        }
        .aspectRatio(1206.0 / 2622.0, contentMode: .fit)
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
    }

    @ViewBuilder
    private var screen: some View {
        if let image = UIImage(named: imageName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color.secondary.opacity(0.12)
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// The final onboarding screen: live-checks whether a Wallet Import has reached the app.
///
/// We can't read the user's Shortcuts automations, so we confirm the sync the only reliable way:
/// once `WalletImportIntent` has successfully run at least once it flips a flag, and this screen
/// updates to "Apple Wallet sync complete." Until then it waits.
private struct SyncCheckView: View {
    @AppStorage(WalletImportIntent.receivedKey) private var received = false

    var body: some View {
        VStack(spacing: 16) {
            if received {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60, weight: .regular))
                    .foregroundStyle(.green)
                Text("Apple Wallet sync complete")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
            } else {
                ProgressView()
                    .controlSize(.large)
                Text("Waiting for your first transaction…")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("Make a real Apple Pay purchase to confirm it's working. This updates automatically.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut, value: received)
        .onChange(of: received) { _, isDone in
            if isDone { Haptics.success() }
        }
    }
}

#Preview {
    OnboardingFlow()
}
