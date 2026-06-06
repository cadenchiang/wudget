import SwiftUI

/// Account profile screen: editable photo and name, signed-in identity, Log Out,
/// and permanent account deletion (App Store guideline 5.1.1(v)).
struct AccountView: View {
    @Environment(AccountStore.self) private var account
    /// Injected by the settings page so its row shows the identical avatar.
    let avatarStore: ProfileAvatarStore
    @State private var editingName = false
    @State private var nameInput = ""
    @State private var nameSaveFailed = false
    @State private var confirmLogout = false
    @State private var confirmDelete = false
    @State private var isDeleting = false
    @State private var deleteFailed = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    ProfileAvatarView(store: avatarStore, name: account.displayName)
                    VStack(alignment: .leading, spacing: 2) {
                        Button {
                            nameInput = account.displayName ?? ""
                            editingName = true
                        } label: {
                            HStack(spacing: 6) {
                                Text(account.displayName ?? "Add Your Name")
                                    .font(.headline)
                                    .foregroundStyle(account.displayName == nil ? .secondary : .primary)
                                    .lineLimit(1)
                                Image(systemName: "pencil")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit name")
                        // Apple's private-relay addresses are machine-generated
                        // noise; show only addresses a person would recognize.
                        if let email = account.email, !Self.isPrivateRelay(email) {
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        if let provider = account.provider {
                            Text("Signed in with \(provider)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 6)
            }

            Section {
                Button("Log Out") { confirmLogout = true }
                    .foregroundStyle(.primary)
                Button(role: .destructive) { confirmDelete = true } label: {
                    if isDeleting {
                        ProgressView()
                    } else {
                        Text("Delete Account")
                    }
                }
                .disabled(isDeleting)
            } footer: {
                Text("Deleting your account permanently removes your data from Orbit.")
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .hidesRootTabBar()
        .alert("Edit name", isPresented: $editingName) {
            TextField("Your name", text: $nameInput)
                .textInputAutocapitalization(.words)
            Button("Save") { Task { await saveName() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Shown on your profile instead of your email.")
        }
        .alert("Couldn't save your name", isPresented: $nameSaveFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please check your connection and try again.")
        }
        .alert("Log out of Orbit?", isPresented: $confirmLogout) {
            Button("Log Out", role: .destructive) {
                Haptics.tap()
                account.signOut()
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete your account?", isPresented: $confirmDelete) {
            Button("Delete Account", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account and cannot be undone.")
        }
        .alert("Couldn't delete account", isPresented: $deleteFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please check your connection and try again.")
        }
    }

    /// Whether an email is an Apple Sign-in private-relay address (random
    /// machine-generated localpart, e.g. "x9f3kq2@privaterelay.appleid.com").
    /// - Parameter email: the address to test.
    /// - Returns: true when the address is relay-generated and shouldn't be shown.
    nonisolated static func isPrivateRelay(_ email: String) -> Bool {
        email.lowercased().hasSuffix("@privaterelay.appleid.com")
    }

    /// Persists the edited display name; failure keeps the previous name and alerts.
    private func saveName() async {
        do {
            try await account.updateDisplayName(nameInput)
            Haptics.success()
        } catch {
            nameSaveFailed = true
        }
    }

    /// Runs the irreversible server-side deletion; failures keep the session so
    /// the user can retry.
    private func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await account.deleteAccount()
            Haptics.success()
        } catch {
            deleteFailed = true
        }
    }
}
