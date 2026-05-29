import SwiftUI
import UIKit

/// The very first screen on launch: a clean (no colored background) landing with an iPhone mockup
/// in the center that animates up into place, an app title, and two choices:
/// "Get Started" (new users → onboarding) and "Already have an account? Sign In" (→ login).
struct WelcomeLandingView: View {
    /// Called when the user taps "Get Started".
    let onGetStarted: () -> Void
    /// Called when the user taps "Already have an account? Sign In".
    let onSignIn: () -> Void

    /// Drives the pop-up entrance animation.
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            phoneMockup
                .frame(maxWidth: 230)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.9)
                .offset(y: appeared ? 0 : 28)

            Text("Spend smart, save more")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.top, 32)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

            Spacer(minLength: 24)

            buttons
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) { appeared = true }
        }
    }

    /// The two stacked actions at the bottom.
    private var buttons: some View {
        VStack(spacing: 14) {
            Button {
                Haptics.tap()
                onGetStarted()
            } label: {
                Text("Get Started")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.black)

            Button {
                Haptics.tap()
                onSignIn()
            } label: {
                Text("Already have an account? **Sign In**")
                    .font(.subheadline)
                    .foregroundStyle(.black)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    /// A small iPhone mockup showing the app's first onboarding screenshot (placeholder if absent).
    private var phoneMockup: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(.black)
            mockScreen
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
        .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
    }

    @ViewBuilder
    private var mockScreen: some View {
        if let image = UIImage(named: "onboarding2") {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color(.secondarySystemBackground)
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    WelcomeLandingView(onGetStarted: {}, onSignIn: {})
}
