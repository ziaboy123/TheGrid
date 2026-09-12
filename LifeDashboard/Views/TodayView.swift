import SwiftUI
import SwiftData
import EventKit

private let addMailAccountTag = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MailAccount.order) private var mailAccounts: [MailAccount]
    @State private var calendarService = CalendarService()
    @Environment(\.scenePhase) private var scenePhase
    @State private var isAddingMailAccount = false
    @State private var unreadCounts: [UUID: Int] = [:]
    @State private var unreadErrors: [UUID: String] = [:]
    @State private var tapSelection: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List(selection: $tapSelection) {
                Section {
                    calendarContent
                } header: {
                    Text("Today's Agenda")
                } footer: {
                    Text("Shows every calendar on your device — including any you've subscribed to, like a university timetable link added in Settings → Calendar.")
                }
                .listRowBackground(ClaudeTheme.surface)

                Section {
                    ForEach(mailAccounts) { account in
                        mailAccountRow(account)
                    }
                    .onDelete(perform: deleteMailAccounts)

                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(ClaudeTheme.accent)
                        Text("Add Account")
                            .foregroundStyle(ClaudeTheme.accent)
                    }
                    .tag(addMailAccountTag)
                } header: {
                    Text("Unread Mail")
                } footer: {
                    if mailAccounts.isEmpty {
                        Text("iCloud only, via an app-specific password — nothing is sent anywhere but Apple's mail server.")
                    }
                }
                .listRowBackground(ClaudeTheme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(GridBackground())
            .navigationTitle("Today")
        }
        .sheet(isPresented: $isAddingMailAccount) {
            AddMailAccountView()
        }
        .onChange(of: tapSelection) { _, newSelection in
            if newSelection.contains(addMailAccountTag) {
                isAddingMailAccount = true
            }
            tapSelection = []
        }
        .task {
            if calendarService.authorizationStatus == .notDetermined {
                await calendarService.requestAccess()
            } else {
                calendarService.refreshTodaysEvents()
            }
            refreshMailAccounts()
            await NotificationService.requestAuthorizationAndSchedule()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            calendarService.refreshTodaysEvents()
            refreshMailAccounts()
        }
        .onChange(of: mailAccounts.count) {
            refreshMailAccounts()
        }
    }

    private func mailAccountRow(_ account: MailAccount) -> some View {
        HStack {
            Image(systemName: "envelope.badge")
                .foregroundStyle(ClaudeTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.email)
                    .foregroundStyle(ClaudeTheme.textPrimary)
                Text(account.provider.displayName)
                    .font(.caption2)
                    .foregroundStyle(ClaudeTheme.textSecondary)
            }
            Spacer()
            if let error = unreadErrors[account.uuid] {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 140)
            } else if let count = unreadCounts[account.uuid] {
                Text("\(count)")
                    .font(.headline)
                    .foregroundStyle(ClaudeTheme.accent)
            } else {
                ProgressView()
            }
        }
    }

    private func refreshMailAccounts() {
        for account in mailAccounts {
            let id = account.uuid
            unreadErrors[id] = nil
            Task {
                do {
                    unreadCounts[id] = try await fetchUnreadCount(for: account)
                    unreadErrors[id] = nil
                } catch {
                    unreadErrors[id] = error.localizedDescription
                }
            }
        }
    }

    private func fetchUnreadCount(for account: MailAccount) async throws -> Int {
        guard let password = KeychainService.readPassword(for: account.uuid.uuidString) else {
            throw MailUnreadError.loginFailed
        }
        return try await MailUnreadService().fetchUnreadCount(
            email: account.email,
            appPassword: password,
            provider: account.provider
        )
    }

    private func deleteMailAccounts(at offsets: IndexSet) {
        for index in offsets {
            let account = mailAccounts[index]
            KeychainService.deletePassword(for: account.uuid.uuidString)
            unreadCounts[account.uuid] = nil
            unreadErrors[account.uuid] = nil
            modelContext.delete(account)
        }
    }

    @ViewBuilder
    private var calendarContent: some View {
        switch calendarService.authorizationStatus {
        case .notDetermined:
            HStack {
                ProgressView()
                Text("Requesting calendar access…")
                    .foregroundStyle(ClaudeTheme.textSecondary)
            }
        case .denied, .restricted:
            VStack(alignment: .leading, spacing: 4) {
                Text("Calendar access denied")
                    .foregroundStyle(ClaudeTheme.textPrimary)
                Text("Enable it in Settings → Privacy → Calendars to see today's agenda.")
                    .font(.caption)
                    .foregroundStyle(ClaudeTheme.textSecondary)
            }
        case .fullAccess:
            if calendarService.todaysEvents.isEmpty {
                Text("Nothing scheduled today.")
                    .foregroundStyle(ClaudeTheme.textSecondary)
            } else {
                ForEach(calendarService.todaysEvents, id: \.eventIdentifier) { event in
                    eventRow(event)
                }
            }
        default:
            Text("Calendar access needed.")
                .foregroundStyle(ClaudeTheme.textSecondary)
        }
    }

    private func eventRow(_ event: EKEvent) -> some View {
        HStack(alignment: .top) {
            Text(timeLabel(for: event))
                .font(.caption.monospacedDigit())
                .foregroundStyle(ClaudeTheme.accent)
                .frame(width: 56, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .foregroundStyle(ClaudeTheme.textPrimary)
                if let calendarTitle = event.calendar?.title {
                    Text(calendarTitle)
                        .font(.caption2)
                        .foregroundStyle(ClaudeTheme.textSecondary)
                }
            }
        }
    }

    private func timeLabel(for event: EKEvent) -> String {
        if event.isAllDay { return "All day" }
        return event.startDate.formatted(date: .omitted, time: .shortened)
    }
}
