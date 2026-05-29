import SwiftUI

/// Wraps content behind a biometric/passcode lock when "Require Face ID" is enabled.
///
/// Locks on entering the background and prompts to unlock when the app becomes active. If no
/// biometrics/passcode are available the content stays accessible (see `AppLock.authenticate`).
struct AppLockGate<Content: View>: View {
    @AppStorage(AppLock.enabledKey) private var lockEnabled = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var unlocked = false
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
        .onAppear(perform: activate)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: activate()
            case .background: if lockEnabled { unlocked = false }
            default: break
            }
        }
    }

    private func activate() {
        if !lockEnabled { unlocked = true; return }
        if !unlocked { AppLock.authenticate { unlocked = $0 } }
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
                Button("Unlock") { AppLock.authenticate { unlocked = $0 } }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.primary)
            }
        }
    }
}
