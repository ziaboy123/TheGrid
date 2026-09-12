import SwiftUI

@Observable
final class DeepLinkRouter {
    var pendingBoardUUID: UUID?
}

struct RootTabView: View {
    @State private var selectedTab = 0
    @Environment(DeepLinkRouter.self) private var router

    var body: some View {
        TabView(selection: $selectedTab) {
            MonthCalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(0)
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(1)
            BoardsListView()
                .tabItem { Label("Boards", systemImage: "square.grid.2x2") }
                .tag(2)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(3)
        }
        .onAppear {
            // Covers the cold-launch case: the deep link fired while the
            // lock screen owned .onOpenURL (RootTabView didn't exist yet),
            // so pendingBoardUUID may already be set by the time we mount.
            if router.pendingBoardUUID != nil {
                selectedTab = 2
            }
        }
        .onChange(of: router.pendingBoardUUID) { _, newValue in
            if newValue != nil {
                selectedTab = 2
            }
        }
    }
}
