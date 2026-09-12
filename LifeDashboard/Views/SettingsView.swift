import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Board> { $0.deletedAt == nil }) private var boards: [Board]
    @Query private var mailAccounts: [MailAccount]

    @State private var schedule = NotificationService.schedule
    @State private var backupResultMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach($schedule) { $day in
                        HStack {
                            Toggle(isOn: $day.isEnabled) {
                                Text(NotificationService.weekdayName(day.weekday))
                            }
                            if day.isEnabled {
                                DatePicker("", selection: timeBinding(for: $day), displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .fixedSize()
                            }
                        }
                    }
                    .onChange(of: schedule) { _, newValue in
                        NotificationService.updateSchedule(newValue)
                    }
                } header: {
                    Text("Daily Reminder")
                } footer: {
                    Text("A notification per day you enable, reminding you to check today's agenda and mail — it always says the same thing, since there's no backend to keep live content fresh in a notification.")
                }

                Section {
                    Button(action: backUpNow) {
                        Label("Back Up to iCloud", systemImage: "icloud.and.arrow.up")
                    }
                    Button(action: restoreFromICloud) {
                        Label("Restore from iCloud", systemImage: "icloud.and.arrow.down")
                    }
                    if let lastBackup = BackupService.lastBackupDate {
                        HStack {
                            Text("Last backup")
                            Spacer()
                            Text(lastBackup.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(ClaudeTheme.textSecondary)
                        }
                    }
                } header: {
                    Text("iCloud Backup")
                } footer: {
                    Text("Backs up your boards to iCloud Drive → The Grid. iCloud and Gmail mail accounts are backed up by email/provider only — never your password.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(GridBackground())
            .navigationTitle("Settings")
            .alert("iCloud Backup", isPresented: backupResultBinding, presenting: backupResultMessage) { _ in
                Button("OK") { backupResultMessage = nil }
            } message: { message in
                Text(message)
            }
        }
        .preferredColorScheme(.dark)
        .tint(ClaudeTheme.accent)
    }

    private func timeBinding(for day: Binding<NotificationService.DaySchedule>) -> Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = day.wrappedValue.hour
                components.minute = day.wrappedValue.minute
                return Calendar.current.date(from: components) ?? .now
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                day.wrappedValue.hour = components.hour ?? 8
                day.wrappedValue.minute = components.minute ?? 0
            }
        )
    }

    private var backupResultBinding: Binding<Bool> {
        Binding(
            get: { backupResultMessage != nil },
            set: { if !$0 { backupResultMessage = nil } }
        )
    }

    private func backUpNow() {
        do {
            try BackupService.backup(boards: boards, mailAccounts: mailAccounts)
            backupResultMessage = "Backed up \(boards.count) board\(boards.count == 1 ? "" : "s") to iCloud Drive → The Grid."
        } catch {
            backupResultMessage = error.localizedDescription
        }
    }

    private func restoreFromICloud() {
        do {
            let count = try BackupService.restore(into: modelContext, existingBoards: boards)
            backupResultMessage = count == 0
                ? "Nothing new to restore — your backup matches what's already here."
                : "Restored \(count) board\(count == 1 ? "" : "s") from iCloud Drive."
        } catch {
            backupResultMessage = error.localizedDescription
        }
    }
}
