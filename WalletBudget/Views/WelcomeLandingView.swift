import SwiftUI

/// Welcome / landing screen, Robinhood-style: the animated budget orrery stays fixed on top, the
/// copy beneath swipes through four pages (only the text moves), and the Log in / Sign up pills
/// stay pinned to the bottom. Full-bleed brand blue with white line art and text throughout.
struct WelcomeLandingView: View {
    @Environment(AccountStore.self) private var account

    /// Current page of the swipeable copy.
    @State private var page = 0
    /// Whether the sign-in bottom sheet is showing.
    @State private var showingAuth = false

    /// The swipeable copy: one short pitch per page. Only this block changes on swipe.
    /// Titles carry an explicit line break so each renders on two lines, Robinhood-style.
    private static let pages: [(title: String, subtitle: String)] = [
        ("Welcome to\nBudget",
         "See every dollar you spend, the moment you spend it."),
        ("Tracking on\nautopilot",
         "Apple Pay purchases import themselves with the amount, merchant, and card."),
        ("Budgets\nthat stick",
         "Set a monthly limit and watch your progress across clear categories."),
        ("Private by\ndesign",
         "Your spending stays on your device, locked behind Face ID."),
    ]

    var body: some View {
        ZStack {
            Color.brandBlue.ignoresSafeArea()

            VStack(spacing: 0) {
                BudgetHeroAnimation()
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .padding(.top, 32)

                TabView(selection: $page) {
                    ForEach(Array(Self.pages.enumerated()), id: \.offset) { index, content in
                        pageCopy(content, isFirst: index == 0)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageDots
                    .padding(.bottom, 20)

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

    /// One page of copy: bold title, supporting line, and a swipe hint on the first page.
    private func pageCopy(_ content: (title: String, subtitle: String), isFirst: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(content.title)
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(content.subtitle)
                .font(.system(size: 17))
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
            if isFirst {
                Text("Swipe to learn more →")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 6)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.top, 28)
    }

    /// Custom page indicator: the current dot solid white, the rest translucent.
    private var pageDots: some View {
        HStack(spacing: 9) {
            ForEach(Self.pages.indices, id: \.self) { index in
                Circle()
                    .fill(.white.opacity(index == page ? 1 : 0.35))
                    .frame(width: 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: page)
    }

    /// The fixed bottom CTAs: outlined Log in beside a solid white Sign up. Both raise the same
    /// auth sheet, which handles new and returning accounts alike.
    private var authButtons: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.tap()
                showingAuth = true
            } label: {
                Text("Log in")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .overlay(Capsule().strokeBorder(.white.opacity(0.9), lineWidth: 1))
            }
            Button {
                Haptics.tap()
                showingAuth = true
            } label: {
                Text("Sign up")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Capsule().fill(.white))
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WelcomeLandingView()
        .environment(AccountStore())
}
