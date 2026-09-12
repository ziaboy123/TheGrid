import SwiftUI
import SwiftData

@main
struct LifeDashboardApp: App {
    static let appGroupID = "group.uk.co.daniyalzia.LifeDashboard"

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Board.self, BoardItem.self, MailAccount.self])
        // CloudKit sync needs a real Apple Developer signing team on the build —
        // without one the mirroring delegate crashes on launch trying to reach a
        // container it has no entitlement for. Local-only until Xcode is signed
        // into a real account; see plan's CloudKit verification note.
        let storeURL = Self.sharedStoreURL()
        Self.migrateOldStoreIfNeeded(to: storeURL)
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: storeURL
        )
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .preferredColorScheme(.dark)
                .tint(ClaudeTheme.accent)
        }
        .modelContainer(sharedModelContainer)
    }

    /// The widget extension needs to read the same store the app writes to —
    /// that requires the store to live in the shared App Group container
    /// rather than the app's own default local container.
    private static func sharedStoreURL() -> URL {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            fatalError("App Group container unavailable — check the 'group.uk.co.daniyalzia.LifeDashboard' entitlement.")
        }
        return containerURL.appendingPathComponent("LifeDashboard.sqlite")
    }

    /// Best-effort, one-time copy of the pre-widget local store into the
    /// shared container, so upgrading doesn't lose existing boards. Silent
    /// no-op if there's nothing to migrate or the old store isn't where
    /// expected — this only matters for devices that ran the app before the
    /// widget existed.
    private static func migrateOldStoreIfNeeded(to newStoreURL: URL) {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: newStoreURL.path) else { return }
        guard let appSupportURL = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return }

        let oldStoreURL = appSupportURL.appendingPathComponent("default.store")
        guard fileManager.fileExists(atPath: oldStoreURL.path) else { return }

        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: oldStoreURL.path + suffix)
            let destination = URL(fileURLWithPath: newStoreURL.path + suffix)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            try? fileManager.copyItem(at: source, to: destination)
        }
    }
}

private struct AppRootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            LockGateView()
        } else {
            OnboardingView {
                hasCompletedOnboarding = true
            }
        }
    }
}

private struct LockGateView: View {
    @State private var lockScreenService = LockScreenService()
    @State private var router = DeepLinkRouter()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if lockScreenService.isUnlocked {
                RootTabView()
            } else {
                LockScreenView(lockScreenService: lockScreenService)
            }
        }
        .environment(router)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                lockScreenService.lock()
            }
        }
        .onOpenURL { url in
            // Attached here (not on RootTabView) because this view is mounted
            // even while the lock screen is showing — a widget deep link on a
            // cold, locked launch needs somewhere to land before RootTabView
            // exists. RootTabView picks up pendingBoardUUID once it appears.
            guard url.scheme == "lifedashboard",
                  url.host == "board",
                  let uuidString = url.pathComponents.last,
                  let uuid = UUID(uuidString: uuidString) else { return }
            router.pendingBoardUUID = uuid
        }
    }
}
