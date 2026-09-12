import SwiftUI
import SwiftData

struct AddMailAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MailAccount.order) private var accounts: [MailAccount]

    @State private var email = ""
    @State private var appPassword = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("iCloud email address", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                    SecureField("App-specific password", text: $appPassword)
                } footer: {
                    Text("Generate one at appleid.apple.com → Sign-In and Security → App-Specific Passwords. Your regular Apple ID password won't work here.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(ClaudeTheme.background)
            .navigationTitle("Add iCloud Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(email.trimmingCharacters(in: .whitespaces).isEmpty || appPassword.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(ClaudeTheme.accent)
    }

    private func save() {
        let account = MailAccount(
            email: email.trimmingCharacters(in: .whitespaces),
            provider: .icloud,
            order: accounts.count
        )
        modelContext.insert(account)
        KeychainService.savePassword(appPassword, for: account.uuid.uuidString)
        dismiss()
    }
}
