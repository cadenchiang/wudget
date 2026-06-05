import Lottie
import SwiftUI

/// Welcome / landing screen: black and white, with a looping Lottie animation (Al Boardman's
/// minimal geometric "9 squares" loop, recolored monochrome and bundled as welcomeHero.json)
/// in the middle of the screen and simple Sign up / Log in pills at the bottom. Both buttons
/// raise the same auth sheet (Apple / Google / Email).
struct WelcomeLandingView: View {
    @Environment(AccountStore.self) private var account
    @Environment(\.colorScheme) private var colorScheme

    /// Whether the sign-in bottom sheet is showing.
    @State private var showingAuth = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Centered in the space above the buttons (not the full screen), so the
                // animation sits at the optical center rather than reading low.
                Spacer()
                hero
                Spacer()
                authButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $showingAuth) {
            AuthSheet()
                .environment(account)
                .presentationDetents([.height(430)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
    }

    /// The hero: the morphing monochrome ring loop orbiting a softly breathing dollar sign,
    /// so the geometry reads as money in motion.
    private var hero: some View {
        ZStack {
            LottieView(animation: .named("welcomeHero"))
                .playing(loopMode: .loop)
                // The artwork is authored black; flip every stroke/fill white in dark mode so
                // the line art stays visible on either system background.
                .valueProvider(
                    ColorValueProvider(colorScheme == .dark
                        ? LottieColor(r: 1, g: 1, b: 1, a: 1)
                        : LottieColor(r: 0, g: 0, b: 0, a: 1)),
                    for: AnimationKeypath(keypath: "**.Color")
                )
                .frame(width: 300, height: 300)

            // The piggy bank floats organically — a slow Lissajous drift with breathing scale
            // and a slight tilt — so it lives inside the ring motion instead of sitting frozen.
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                PiggyBankIcon()
                    .frame(width: 64, height: 54)
                    .scaleEffect(1 + 0.06 * sin(t * 1.5))
                    .rotationEffect(.degrees(4 * sin(t * 0.9)))
                    .offset(x: 5 * sin(t * 0.7), y: 6 * sin(t * 1.13))
            }
            .accessibilityHidden(true)
        }
    }

    /// The bottom CTAs: a solid Sign up pill over an outlined Log in pill, both monochrome.
    private var authButtons: some View {
        VStack(spacing: 12) {
            Button {
                Haptics.tap()
                showingAuth = true
            } label: {
                Text("Sign up")
                    .font(.headline)
                    .foregroundStyle(Color(.systemBackground))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Capsule().fill(Color.primary))
            }
            Button {
                Haptics.tap()
                showingAuth = true
            } label: {
                Text("Log in")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .overlay(Capsule().strokeBorder(Color.primary.opacity(0.3), lineWidth: 1))
            }
        }
        .buttonStyle(.plain)
    }
}

/// A super-minimal line-art piggy bank, drawn to match the welcome rings: body, snout, ear,
/// eye, legs, and a coin slot, stroked in `.primary` (no SF Symbol exists for this).
private struct PiggyBankIcon: View {
    var body: some View {
        Canvas { context, size in
            // Designed on a 72x60 grid, scaled to whatever frame hosts it.
            let sx = size.width / 72
            let sy = size.height / 60
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }
            let stroke = StrokeStyle(lineWidth: 3.5 * min(sx, sy), lineCap: .round, lineJoin: .round)
            let color = GraphicsContext.Shading.color(.primary)

            // Body
            var body = Path()
            body.addEllipse(in: CGRect(x: 6 * sx, y: 14 * sy, width: 50 * sx, height: 36 * sy))
            context.stroke(body, with: color, style: stroke)

            // Snout poking out the right side
            var snout = Path(roundedRect: CGRect(x: 54 * sx, y: 26 * sy, width: 12 * sx, height: 13 * sy),
                             cornerRadius: 5 * min(sx, sy))
            context.stroke(snout, with: color, style: stroke)

            // Ear
            var ear = Path()
            ear.move(to: pt(40, 16))
            ear.addQuadCurve(to: pt(48, 18), control: pt(45, 8))
            context.stroke(ear, with: color, style: stroke)

            // Eye
            let eye = Path(ellipseIn: CGRect(x: 43 * sx, y: 24 * sy, width: 4 * sx, height: 4 * sy))
            context.fill(eye, with: color)

            // Coin slot on top
            var slot = Path()
            slot.move(to: pt(22, 12))
            slot.addLine(to: pt(32, 12))
            context.stroke(slot, with: color, style: stroke)

            // Legs
            for x in [18.0, 42.0] {
                var leg = Path()
                leg.move(to: pt(x, 49))
                leg.addLine(to: pt(x, 57))
                context.stroke(leg, with: color, style: stroke)
            }
        }
    }
}

#Preview {
    WelcomeLandingView()
        .environment(AccountStore())
}
