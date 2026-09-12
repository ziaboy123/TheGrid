import SwiftUI
import EventKit

struct MonthCalendarView: View {
    @State private var calendarService = CalendarService()
    @State private var visibleMonth: Date = Calendar.current.startOfDay(for: .now)
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: .now)

    private var calendar: Calendar { Calendar.current }
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    private var eventsByDay: [Date: [EKEvent]] {
        calendarService.eventsByDay(forMonthContaining: visibleMonth)
    }

    private var selectedDayEvents: [EKEvent] {
        eventsByDay[calendar.startOfDay(for: selectedDay)] ?? []
    }

    private var monthDays: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: visibleMonth) else { return [] }
        let firstOfMonth = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for offset in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: offset, to: firstOfMonth) {
                days.append(date)
            }
        }
        return days
    }

    private var monthTitle: String {
        visibleMonth.formatted(.dateTime.month(.wide).year())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    monthHeader
                    weekdayRow
                    dayGrid
                    Rectangle()
                        .fill(ClaudeTheme.border)
                        .frame(height: 1)
                    selectedDaySection
                }
                .padding()
            }
            .background(GridBackground())
            .navigationTitle("Calendar")
            .task {
                if calendarService.authorizationStatus == .notDetermined {
                    await calendarService.requestAccess()
                }
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(monthTitle)
                .font(.title3.bold())
                .foregroundStyle(ClaudeTheme.textPrimary)
            Spacer()
            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .tint(ClaudeTheme.accent)
    }

    private var weekdayRow: some View {
        HStack {
            ForEach(shiftedWeekdaySymbols(), id: \.self) { symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ClaudeTheme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var dayGrid: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isToday = calendar.isDateInToday(day)
        let hasEvents = !(eventsByDay[calendar.startOfDay(for: day)]?.isEmpty ?? true)

        return Button {
            selectedDay = day
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.callout.weight(isToday ? .bold : .regular))
                    .foregroundStyle(isSelected ? ClaudeTheme.background : (isToday ? ClaudeTheme.accent : ClaudeTheme.textPrimary))
                    .frame(width: 32, height: 32)
                    .background(isSelected ? ClaudeTheme.accent : Color.clear, in: Circle())
                    .overlay(
                        Circle().stroke(isToday && !isSelected ? ClaudeTheme.accent : .clear, lineWidth: 1)
                    )

                Circle()
                    .fill(hasEvents ? ClaudeTheme.accent : .clear)
                    .frame(width: 4, height: 4)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.headline)
                .foregroundStyle(ClaudeTheme.textPrimary)

            if !calendarService.isAuthorized {
                Text("Calendar access needed. Enable it in Settings → Privacy → Calendars.")
                    .font(.caption)
                    .foregroundStyle(ClaudeTheme.textSecondary)
            } else if selectedDayEvents.isEmpty {
                Text("Nothing scheduled.")
                    .foregroundStyle(ClaudeTheme.textSecondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(selectedDayEvents.enumerated()), id: \.element.eventIdentifier) { index, event in
                        if index > 0 {
                            Rectangle().fill(ClaudeTheme.border).frame(height: 1)
                        }
                        eventRow(event)
                    }
                }
                .padding(12)
                .background(ClaudeTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func timeLabel(for event: EKEvent) -> String {
        if event.isAllDay { return "All day" }
        return event.startDate.formatted(date: .omitted, time: .shortened)
    }

    private func changeMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: visibleMonth) else { return }
        visibleMonth = newMonth
    }

    private func shiftedWeekdaySymbols() -> [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let firstWeekdayIndex = calendar.firstWeekday - 1
        return Array(symbols[firstWeekdayIndex...] + symbols[..<firstWeekdayIndex])
    }
}
