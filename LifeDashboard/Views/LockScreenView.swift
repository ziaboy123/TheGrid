import SwiftUI

struct LockScreenView: View {
    let lockScreenService: LockScreenService

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(ClaudeTheme.accent)

            Text("The Grid is locked")
                .font(.headline)
                .foregroundStyle(ClaudeTheme.textPrimary)

            Button {
                Task { await lockScreenService.authenticate() }
            } label: {
                if lockScreenService.isAuthenticating {
                    ProgressView()
                } else {
                    Text("Unlock")
                        .frame(maxWidth: 200)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(ClaudeTheme.accent)
            .disabled(lockScreenService.isAuthenticating)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GridBackground())
        .task {
            await lockScreenService.authenticate()
        }
    }
}
