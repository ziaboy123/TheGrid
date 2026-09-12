import SwiftUI

struct LockScreenView: View {
    let lockScreenService: LockScreenService

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(ClaudeTheme.accent)

            Text("Life Dashboard is locked")
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
        .background(ClaudeTheme.background.ignoresSafeArea())
        .task {
            await lockScreenService.authenticate()
        }
    }
}
