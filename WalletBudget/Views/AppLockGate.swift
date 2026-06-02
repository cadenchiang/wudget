import SwiftUI

/// Wraps content behind a biometric/passcode lock when "Require Face ID" is enabled.
///
/// Locks on entering the background and prompts to unlock when the app becomes active. If no
/// biometrics/passcode are available the content stays accessible (see `AppLock.authenticate`).
struct AppLockGate<Content: View>: View {
    @AppStorage(AppLock.enabledKey) private var lockEnabled = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var unlocked = false
    /// True while a biometric prompt is in flight. Guards against overlapping evaluations
    /// (onAppear + scene-phase both firing), which would cancel each other and leave the
    /// Unlock button looking dead.
    @State private var authenticating = false
    private let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        ZStack {
            content
            if lockEnabled && !unlocked {
                lockScreen.transition(.opacity)
            }
        }
        .animation(.easeInOut, value: unlocked)
        .onAppear(perform: authenticateIfNeeded)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                authenticateIfNeeded()
            case .background:
                // Re-lock on background, but not while a prompt is mid-flight (the biometric
                // sheet can briefly drop the scene to inactive/background and would otherwise
                // reset state under the running evaluation).
                if lockEnabled && !authenticating { unlocked = false }
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
            unlocked = success
        }
    }

    private var lockScreen: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text("Wudget is locked")
                    .font(.headline)
                Button("Unlock") { authenticateIfNeeded() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.primary)
            }
        }
    }
}
