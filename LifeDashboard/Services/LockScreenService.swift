import Foundation
import LocalAuthentication

@Observable
final class LockScreenService {
    private(set) var isUnlocked = false
    private(set) var isAuthenticating = false

    func lock() {
        isUnlocked = false
    }

    func authenticate() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        let context = LAContext()
        let reason = "Unlock The Grid"

        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            isUnlocked = success
        } catch {
            isUnlocked = false
        }
    }
}
