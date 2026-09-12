import Foundation
import EventKit

@Observable
final class CalendarService {
    private let store = EKEventStore()

    private(set) var authorizationStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    private(set) var todaysEvents: [EKEvent] = []

    var isAuthorized: Bool {
        authorizationStatus == .fullAccess
    }

    func requestAccess() async {
        do {
            let granted = try await store.requestFullAccessToEvents()
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            if granted {
                refreshTodaysEvents()
            }
        } catch {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        }
    }

    func refreshTodaysEvents() {
        guard isAuthorized else { return }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: .now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        todaysEvents = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
    }
}
