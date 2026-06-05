import SwiftUI

/// Account profile screen: editable photo and name, signed-in identity, Log Out,
/// and permanent account deletion (App Store guideline 5.1.1(v)).
struct AccountView: View {
    @Environment(AccountStore.self) private var account
    @State private var avatarStore = ProfileAvatarStore()
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
                                Text(account.displayName ?? account.email ?? "Account")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Image(systemName: "pencil")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit name")
                        if account.displayName != nil, let email = account.email {
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
                Button(role: .destructive) { confirmLogout = true } label: {
                    Text("Log Out").frame(maxWidth: .infinity)
                }
            }

            Section {
                Button(role: .destructive) { confirmDelete = true } label: {
                    if isDeleting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Delete Account").frame(maxWidth: .infinity)
                    }
                }
                .disabled(isDeleting)
            } footer: {
                Text("Permanently deletes your Orbit account. Spending data stored on this device is removed when you delete the app.")
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
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
