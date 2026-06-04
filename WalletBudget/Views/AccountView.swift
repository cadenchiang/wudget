import SwiftUI

/// Account profile screen: shows the signed-in identity and a Log Out action.
struct AccountView: View {
    @Environment(AccountStore.self) private var account
    @State private var confirmLogout = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(.gray)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.email ?? "Account")
                            .font(.headline)
                            .lineLimit(1)
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
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Log out of Budget?", isPresented: $confirmLogout) {
            Button("Log Out", role: .destructive) {
                Haptics.tap()
                account.signOut()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
