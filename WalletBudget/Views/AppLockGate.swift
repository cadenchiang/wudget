import SwiftUI

/// Wraps content behind a biometric/passcode lock when "Require Face ID" is enabled.
///
/// Locks on entering the background and prompts to unlock when the app becomes active. If no
/// biometrics/passcode are available the content stays accessible (see `AppLock.authenticate`).
struct AppLockGate<Content: View>: View {
    @AppStorage(AppLock.enabledKey) private var lockEnabled = false
    @Environment(AccountStore.self) private var account
    @Environment(\.scenePhase) private var scenePhase
    @State private var unlocked = false
    /// True while a biometric prompt is in flight. Guards against overlapping evaluations
    /// (onAppear + scene-phase both firing), which would cancel each other and leave the
    /// Unlock button looking dead.
    @State private var authenticating = false
    /// True after a biometric attempt failed or was cancelled; reveals the Unlock/Log out
    /// buttons. While the first prompt is in flight the lock screen is just the logo.
    @State private var authFailed = false
    @State private var confirmLogout = false
    private let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        ZStack {
            content
            if lockEnabled && !unlocked {
                lockScreen.transition(.opacity)
            }
        }
        .onAppear(perform: authenticateIfNeeded)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                authenticateIfNeeded()
            case .background:
                // Re-lock on background, but not while a prompt is mid-flight (the biometric
                // sheet can briefly drop the scene to inactive/background and would otherwise
                // reset state under the running evaluation).
                if lockEnabled && !authenticating {
                    unlocked = false
                    authFailed = false // next foreground starts with the clean logo-only state
                }
            default:
                break
            }
        }
    }

    /// Prompts for biometrics once. Re-entrant calls (a second scene-phase change, or tapping
    /// Unlock while a prompt is already up) are ignored so only one evaluation ever runs.
    private func authenticateIfNeeded() {
        guard lockEnabled else { unlocked = true; return }
        guard !unlocked, !authenticating else { return }
        authenticating = true
        AppLock.authenticate { success in
            authenticating = false
            guard success else {
                authFailed = true
                return
            }
            // Wait for the system Face ID checkmark HUD to finish its own dismissal before
            // cross-fading the lock screen away; starting both at once makes the unlock glitch.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeInOut(duration: 0.4)) { unlocked = true }
            }
        }
    }

    /// Full-bleed brand-blue screen with just the logo. After a failed/cancelled prompt, a solid
    /// white Unlock capsule (retries Face ID) and an outlined Log out button appear at the bottom.
    private var lockScreen: some View {
        ZStack {
            Color.brandBlue.ignoresSafeArea()

            Image("lockScreenLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                .padding(.top, 150)
                .frame(maxHeight: .infinity, alignment: .top)

            if authFailed {
                VStack(spacing: 12) {
                    Button { authenticateIfNeeded() } label: {
                        Text("Unlock")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Capsule().fill(.white))
                    }
                    Button { confirmLogout = true } label: {
                        Text("Log out")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .overlay(Capsule().strokeBorder(.white.opacity(0.8), lineWidth: 1))
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: authFailed)
        .alert("Log out of Budget?", isPresented: $confirmLogout) {
            Button("Log Out", role: .destructive) { account.signOut() }
            Button("Cancel", role: .cancel) {}
        }
    }
}
