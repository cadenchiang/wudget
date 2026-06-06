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
    /// Whether a Wallet Import has reached the app (drives the green "sync complete" state).
    @AppStorage(WalletImportIntent.receivedKey) private var received = false

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
                Capsule().fill(isLastStep && received ? Color.green : Color.primary)
                    .frame(width: geo.size.width * progress)
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
                // Explicit label color: on the primary-tinted fill the label must invert with
                // the scheme (black on white in dark mode), which borderedProminent won't do.
                .foregroundStyle(isLastStep ? Color.white : Color(.systemBackground))
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
            VStack(spacing: 8) {
                Text(step.title)
                    .font(.title.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                if let subtitle = step.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    private var standardStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Fixed-height header so the phone frame below sits at the same position on every
            // step, regardless of how many lines the title wraps to or whether a button shows.
            VStack(alignment: .leading, spacing: 10) {
                titleView

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
            // FIXED height (not minHeight): every step's phone frame starts at
            // exactly the same y, no matter how tall the title/pill/link is.
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: 104, alignment: .topLeading)

            artwork
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    /// The step title. When `highlightPill` is set, the highlight renders as a blue button-style
    /// pill on its own line; otherwise it falls back to the inline styled `titleText`.
    @ViewBuilder
    private var titleView: some View {
        if step.highlightPill, let highlight = step.highlight,
           let range = step.title.range(of: highlight) {
            let prefix = String(step.title[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            VStack(alignment: .leading, spacing: 12) {
                if !prefix.isEmpty {
                    Text(prefix)
                        .font(.title.bold())
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(highlight)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.blue))
            }
        } else if let highlight = step.highlight, let asset = step.highlightAsset,
                  let range = step.title.range(of: highlight) {
            // Render the asset as a properly sized image (embedding it inline in Text would
            // draw it at full resolution and blow up the screen).
            let prefix = String(step.title[..<range.lowerBound])
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if !prefix.isEmpty { Text(prefix).font(.title.bold()) }
                Image(asset)
                    .resizable().scaledToFit()
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                Text(highlight).font(.title.bold())
            }
            .foregroundStyle(.primary)
        } else {
            // Capped at two lines (shrinking slightly if needed) so the header stays compact and
            // the phone frame below sits at the same height on every step.
            titleText
                .font(.title.bold())
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The step title, with an optional inline SF Symbol and a colored `highlight` substring.
    /// When `symbolReplacesHighlight` is set, the symbol stands in for the highlight words.
    private var titleText: Text {
        guard let highlight = step.highlight, let range = step.title.range(of: highlight) else {
            return Text(step.title).foregroundStyle(.primary)
        }
        let prefix = Text(String(step.title[..<range.lowerBound])).foregroundStyle(.primary)
        let suffix = Text(String(step.title[range.upperBound...])).foregroundStyle(.primary)

        if let symbol = step.highlightSymbol {
            let icon = Text(Image(systemName: symbol)).foregroundStyle(.blue)
            if step.symbolReplacesHighlight {
                return prefix + icon + suffix
            }
            return prefix + icon + Text(" ")
                + Text(highlight).foregroundStyle(step.highlightColored ? .blue : .primary)
                + suffix
        }
        return prefix + Text(highlight).foregroundStyle(step.highlightColored ? .blue : .primary) + suffix
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
            PhoneFrame(imageName: step.imageName, tapPoint: step.tapPoint)
                .frame(maxHeight: 470)
        }
    }
}

/// Renders a full screenshot inside a simple iPhone frame (black bezel, rounded screen) so users
/// see what the step looks like on their phone. Falls back to a placeholder until the screenshot
/// is added to the asset catalog.
private struct PhoneFrame: View {
    let imageName: String
    /// Normalized (0–1) screenshot location where a subtle pulsing ring marks the tap target.
    var tapPoint: CGPoint? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(.black)
            screen
                .clipShape(RoundedRectangle(cornerRadius: 33, style: .continuous))
                .overlay {
                    if let tapPoint {
                        GeometryReader { geo in
                            TapIndicator()
                                .position(x: tapPoint.x * geo.size.width,
                                          y: tapPoint.y * geo.size.height)
                        }
                    }
                }
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

/// A subtle pulsing ring overlaid on a screenshot to mark the control the user should tap.
/// Gently breathes (scale + opacity) so it draws the eye without covering the UI underneath.
private struct TapIndicator: View {
    @State private var pulsing = false

    var body: some View {
        ZStack {
            Circle().fill(Color.blue.opacity(0.15))
            Circle().strokeBorder(Color.blue.opacity(0.8), lineWidth: 2)
        }
        .frame(width: 32, height: 32)
        .scaleEffect(pulsing ? 1.2 : 0.85)
        .opacity(pulsing ? 0.45 : 1)
        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulsing)
        .onAppear { pulsing = true }
        .allowsHitTesting(false)
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
                Text("Any payments you make will now be tracked automatically.")
                    .font(.subheadline.weight(.light))
                    .foregroundStyle(.primary)
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
