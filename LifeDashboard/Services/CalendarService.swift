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

    /// Fetches every event in the month containing `date`, keyed by the
    /// start of the day it falls on — used to dot out days with events in a
    /// month grid without re-querying EventKit per cell.
    func eventsByDay(forMonthContaining date: Date) -> [Date: [EKEvent]] {
        guard isAuthorized else { return [:] }
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else { return [:] }

        let predicate = store.predicateForEvents(withStart: monthInterval.start, end: monthInterval.end, calendars: nil)
        let events = store.events(matching: predicate)

        return Dictionary(grouping: events) { calendar.startOfDay(for: $0.startDate) }
            .mapValues { $0.sorted { $0.startDate < $1.startDate } }
    }
}
