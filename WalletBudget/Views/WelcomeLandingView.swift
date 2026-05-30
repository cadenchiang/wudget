import SwiftUI

/// Welcome / landing screen, in the Nara/Cal-AI style: a phone preview on top, a centered tagline,
/// and a single prominent black "Get Started" pill. Tapping Get Started hands off to sign-in.
struct WelcomeLandingView: View {
    @Environment(AccountStore.self) private var account

    /// Drives the entrance animation (phone fades/slides up, then the CTA panel).
    @State private var appeared = false
    /// Whether the sign-in bottom sheet is showing.
    @State private var showingAuth = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 12)
                phonePreview
                    .frame(maxWidth: 250)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 26)
                Spacer(minLength: 24)
                ctaPanel
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.timingCurve(0.16, 1.0, 0.3, 1.0, duration: 1.0)) { appeared = true }
        }
        .sheet(isPresented: $showingAuth) {
            AuthSheet()
                .environment(account)
                .presentationDetents([.height(430)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
    }

    /// Tagline + the single Get Started CTA, hugging the bottom.
    private var ctaPanel: some View {
        VStack(spacing: 0) {
            Text("Spend smart,\nsave more.")
                .font(.system(size: 34, weight: .bold))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

            Button {
                Haptics.tap()
                showingAuth = true
            } label: {
                Text("Get Started")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Capsule().fill(Color.black))
            }
            Spacer().frame(height: 32)
        }
        .frame(maxWidth: .infinity)
    }

    /// A phone mockup showing a mini version of the spending screen.
    private var phonePreview: some View {
        let bars: [(h: CGFloat, c: Color)] = [(44, .blue), (58, .green), (74, .orange), (92, .purple), (66, .pink)]
        return RoundedRectangle(cornerRadius: 46, style: .continuous)
            .fill(Color.black)
            .aspectRatio(9.0 / 19.0, contentMode: .fit)
            .overlay {
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .padding(6)
                    .overlay(alignment: .top) {
                        VStack(alignment: .leading, spacing: 0) {
                            Capsule().fill(.black)
                                .frame(width: 86, height: 24)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 12)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Total Spending").font(.caption2).foregroundStyle(.secondary)
                                Text("$1,248").font(.title2.bold())
                                Text("$252 left this month").font(.caption2.weight(.medium)).foregroundStyle(.green)
                                HStack(alignment: .bottom, spacing: 6) {
                                    ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(bar.c)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: bar.h)
                                    }
                                }
                                .frame(height: 92, alignment: .bottom)
                                .padding(.top, 4)

                                ForEach(["Blue Bottle", "Whole Foods"], id: \.self) { merchant in
                                    HStack {
                                        Text(merchant).font(.caption2.weight(.medium))
                                        Spacer()
                                        Text(merchant == "Blue Bottle" ? "$6.25" : "$48.10").font(.caption2.weight(.semibold))
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 7)
                                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(.systemBackground)))
                                }
                            }
                            .padding(16)
                            Spacer(minLength: 0)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
            }
            .shadow(color: .black.opacity(0.22), radius: 26, y: 14)
    }
}

#Preview {
    WelcomeLandingView()
}
