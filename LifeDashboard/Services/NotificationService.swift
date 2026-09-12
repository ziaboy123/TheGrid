import Foundation
import UserNotifications

/// A per-weekday static reminder — deliberately not trying to embed live
/// agenda/mail content, since a local notification's content is fixed at
/// schedule time with no backend to keep it fresh. Tapping it just opens the
/// app, where the real Today view shows current data.
enum NotificationService {
    /// `weekday` follows Foundation's convention: 1 = Sunday ... 7 = Saturday.
    struct DaySchedule: Codable, Identifiable, Equatable {
        var weekday: Int
        var isEnabled: Bool
        var hour: Int
        var minute: Int
        var id: Int { weekday }
    }

    private static let scheduleKey = "dailyDigestSchedule"
    private static let identifierPrefix = "uk.co.daniyalzia.LifeDashboard.dailyDigest.weekday."

    /// Monday-first display order — the stored `weekday` values still follow
    /// Foundation's Sunday-first convention underneath.
    static func defaultSchedule() -> [DaySchedule] {
        [2, 3, 4, 5, 6, 7, 1].map { DaySchedule(weekday: $0, isEnabled: true, hour: 8, minute: 0) }
    }

    static var schedule: [DaySchedule] {
        get {
            guard let data = UserDefaults.standard.data(forKey: scheduleKey),
                  let decoded = try? JSONDecoder().decode([DaySchedule].self, from: data),
                  decoded.count == 7 else {
                return defaultSchedule()
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: scheduleKey)
            }
        }
    }

    static func weekdayName(_ weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let index = weekday - 1
        guard symbols.indices.contains(index) else { return "" }
        return symbols[index]
    }

    /// Call once on launch — requests permission if not yet decided, and
    /// (re)applies whatever schedule is currently stored.
    static func requestAuthorizationAndSchedule() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            if let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge]), granted {
                applySchedule()
            }
        case .authorized, .provisional:
            applySchedule()
        default:
            break
        }
    }

    /// Call whenever the user edits the schedule in Settings.
    static func updateSchedule(_ newSchedule: [DaySchedule]) {
        schedule = newSchedule
        applySchedule()
    }

    private static func applySchedule() {
        let center = UNUserNotificationCenter.current()
        let allIdentifiers = (1...7).map { "\(identifierPrefix)\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: allIdentifiers)

        for day in schedule where day.isEnabled {
            let content = UNMutableNotificationContent()
            content.title = "Life Dashboard"
            content.body = "Good morning — check today's agenda and mail."
            content.sound = .default

            var components = DateComponents()
            components.weekday = day.weekday
            components.hour = day.hour
            components.minute = day.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

            let request = UNNotificationRequest(
                identifier: "\(identifierPrefix)\(day.weekday)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }
}
