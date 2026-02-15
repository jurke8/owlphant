import SwiftUI

struct EventsView: View {
    @ObservedObject var viewModel: ContactsViewModel
    @State private var upcomingContactReminders: [UpcomingContactReminder] = []
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScreenBackground {
                ScrollView {
                    VStack(spacing: 18) {
                        timelineCard(title: L10n.tr("events.timeline.recent"), events: recentInteractionEvents, section: .recent)
                        timelineCard(title: todayTitle, events: todayEvents, section: .today)
                        timelineCard(title: tomorrowTitle, events: tomorrowEvents, section: .tomorrow)
                        timelineCard(title: L10n.tr("events.timeline.later"), events: laterEvents, section: .later)

                        Spacer(minLength: 10)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(L10n.tr("tab.events"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await refreshStatusAndSync()
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            Task { await refreshStatusAndSync() }
        }
    }

    private var birthdayContacts: [Contact] {
        viewModel.contacts
            .filter { contact in
                guard let birthday = contact.birthday else { return false }
                return BirthdayValue(rawValue: birthday) != nil
            }
    }

    private var timelineEvents: [TimelineEvent] {
        let birthdayEvents = birthdayContacts.map { contact in
            TimelineEvent(
                id: "birthday.\(contact.id.uuidString)",
                kind: .birthday,
                marker: "🎂",
                title: contact.displayName,
                subtitle: L10n.format("events.item.birthday", birthdayDetails(for: contact)),
                date: nextBirthdayDate(for: contact)
            )
        }

        let meetingEvents = viewModel.upcomingMeetings.map { meeting in
            TimelineEvent(
                id: "meeting.\(meeting.id)",
                kind: .meeting,
                marker: "📅",
                title: meeting.title,
                subtitle: meetingDetails(for: meeting),
                date: meeting.startDate
            )
        }

        let reminderEvents = upcomingContactReminders.map { reminder in
            TimelineEvent(
                id: "reminder.\(reminder.id)",
                kind: .contactReminder,
                marker: reminderMarker(for: reminder),
                title: reminder.contact.displayName,
                subtitle: reminderLabel(for: reminder),
                date: reminder.date
            )
        }

        return (birthdayEvents + meetingEvents + reminderEvents)
            .sorted(by: Self.timelineSort)
    }

    private var recentInteractionEvents: [TimelineEvent] {
        viewModel.contacts
            .flatMap { contact in
                contact.interactions.map { interaction in
                    TimelineEvent(
                        id: "interaction.\(interaction.id.uuidString)",
                        kind: .interaction,
                        marker: "📝",
                        title: contact.displayName,
                        subtitle: interaction.note,
                        date: Date(timeIntervalSince1970: interaction.date)
                    )
                }
            }
            .filter { event in
                guard let date = event.date else { return false }
                return date <= Date()
            }
            .sorted(by: Self.recentTimelineSort)
            .prefix(10)
            .map { $0 }
    }

    private var todayEvents: [TimelineEvent] {
        timelineEvents.filter {
            guard let date = $0.date else { return false }
            return Self.calendar.isDateInToday(date)
        }
    }

    private var tomorrowEvents: [TimelineEvent] {
        timelineEvents.filter {
            guard let date = $0.date else { return false }
            return Self.calendar.isDateInTomorrow(date)
        }
    }

    private var laterEvents: [TimelineEvent] {
        timelineEvents.filter {
            guard let date = $0.date else { return true }
            return !Self.calendar.isDateInToday(date) && !Self.calendar.isDateInTomorrow(date)
        }
    }

    private var todayTitle: String {
        let today = Date()
        let weekday = Self.weekdayFormatter.string(from: today)
        let dayMonth = Self.dayMonthFormatter.string(from: today)
        return "\(L10n.tr("events.timeline.today")) - \(weekday), \(dayMonth)"
    }

    private var tomorrowTitle: String {
        guard let tomorrow = Self.calendar.date(byAdding: .day, value: 1, to: Date()) else {
            return L10n.tr("events.timeline.tomorrow")
        }
        let weekday = Self.weekdayFormatter.string(from: tomorrow)
        let dayMonth = Self.dayMonthFormatter.string(from: tomorrow)
        return "\(L10n.tr("events.timeline.tomorrow")) - \(weekday), \(dayMonth)"
    }

    @ViewBuilder
    private func timelineCard(title: String, events: [TimelineEvent], section: TimelineSection) -> some View {
        SectionCard {
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(AppTheme.text)

            if events.isEmpty {
                Text(section == .recent ? L10n.tr("events.timeline.recentEmpty") : L10n.tr("events.timeline.empty"))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.muted)
            } else if section == .later {
                let grouped = groupedLaterEvents(events: Array(events.prefix(8)))
                ForEach(grouped) { group in
                    Text(group.title)
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(AppTheme.muted)
                        .padding(.top, 2)

                    ForEach(group.events) { event in
                        timelineRow(for: event, section: section)
                    }
                }
            } else {
                ForEach(events.prefix(8)) { event in
                    timelineRow(for: event, section: section)
                }
            }
        }
    }

    private func timelineRow(for event: TimelineEvent, section: TimelineSection) -> some View {
        let label = dateLabel(for: event, section: section)

        return HStack(alignment: .top, spacing: 10) {
            Text(event.marker)
                .font(.system(size: 18))

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(2)

                if let subtitle = event.subtitle {
                    Text(subtitle)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(2)
                }
            }

            Spacer()

            if !label.isEmpty {
                Text(label)
                    .multilineTextAlignment(.trailing)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(2)
            }
        }
    }

    private func refreshStatusAndSync() async {
        let rules = BirthdayReminderRule.loadFromDefaults().sorted(by: Self.ruleSort)
        await BirthdayReminderService.shared.syncAllReminders(for: viewModel.contacts, rules: rules)
        upcomingContactReminders = await BirthdayReminderService.shared.upcomingContactReminders(for: viewModel.contacts)
    }

    private func reminderLabel(for reminder: UpcomingContactReminder) -> String {
        switch reminder.kind {
        case .coffee:
            return L10n.tr("events.contactReminders.coffee")
        case let .stayInTouch(days):
            return L10n.format("events.contactReminders.stayInTouch", days)
        }
    }

    private func reminderMarker(for reminder: UpcomingContactReminder) -> String {
        switch reminder.kind {
        case .coffee:
            return "☕️"
        case .stayInTouch:
            return "🤙"
        }
    }

    private func dateLabel(for event: TimelineEvent, section: TimelineSection) -> String {
        guard let date = event.date else {
            return (section == .later || section == .recent) ? "" : L10n.tr("events.item.dateUnknown")
        }

        switch event.kind {
        case .birthday:
            return ""
        case .meeting, .contactReminder:
            let time = Self.timeFormatter.string(from: date)
            return time
        case .interaction:
            let day = Self.dayMonthFormatter.string(from: date)
            return day
        }
    }

    private func groupedLaterEvents(events: [TimelineEvent]) -> [LaterEventGroup] {
        var groups: [LaterEventGroup] = []

        for event in events {
            let title: String
            if let date = event.date {
                let weekday = Self.weekdayFormatter.string(from: date)
                let dayMonth = Self.dayMonthFormatter.string(from: date)
                title = L10n.format("events.item.dateWithWeekday", weekday, dayMonth)
            } else {
                title = L10n.tr("events.item.dateUnknown")
            }

            if let index = groups.firstIndex(where: { $0.title == title }) {
                groups[index].events.append(event)
            } else {
                groups.append(LaterEventGroup(title: title, events: [event]))
            }
        }

        return groups
    }

    private func displayDate(_ value: String?) -> String {
        guard let value, let birthday = BirthdayValue(rawValue: value) else { return "-" }
        return birthday.displayText
    }

    private func birthdayDetails(for contact: Contact) -> String {
        let dateText = displayDate(contact.birthday)
        guard let upcomingAge = upcomingAge(for: contact) else {
            return dateText
        }
        let ageText = L10n.format("events.item.turningAge", upcomingAge)
        return "\(dateText) (\(ageText))"
    }

    private func upcomingAge(for contact: Contact) -> Int? {
        guard
            let value = contact.birthday,
            let birthday = BirthdayValue(rawValue: value),
            birthday.isFullDate,
            let nextBirthday = nextBirthdayDate(for: contact)
        else {
            return nil
        }

        let birthYear = birthday.year
        let nextBirthdayYear = Self.calendar.component(.year, from: nextBirthday)
        let age = nextBirthdayYear - birthYear
        return age > 0 ? age : nil
    }

    private func meetingDetails(for meeting: UpcomingMeeting) -> String? {
        let parts = [meeting.location, meeting.calendarName].compactMap {
            let trimmed = $0?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (trimmed?.isEmpty == false) ? trimmed : nil
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " | ")
    }

    private func nextBirthdayDate(for contact: Contact) -> Date? {
        guard
            let birthdayValue = contact.birthday,
            let birthday = BirthdayValue(rawValue: birthdayValue),
            let month = birthday.month,
            let day = birthday.day
        else {
            return nil
        }

        let startOfToday = Self.calendar.startOfDay(for: Date())
        let currentYear = Self.calendar.component(.year, from: startOfToday)

        for yearOffset in 0...8 {
            guard let candidate = Self.calendar.date(from: DateComponents(year: currentYear + yearOffset, month: month, day: day)) else {
                continue
            }

            if candidate >= startOfToday {
                return candidate
            }
        }

        return nil
    }

    private static func ruleSort(_ lhs: BirthdayReminderRule, _ rhs: BirthdayReminderRule) -> Bool {
        if lhs.daysBeforeBirthday != rhs.daysBeforeBirthday {
            return lhs.daysBeforeBirthday < rhs.daysBeforeBirthday
        }
        if lhs.hour != rhs.hour {
            return lhs.hour < rhs.hour
        }
        return lhs.minute < rhs.minute
    }

    nonisolated private static func timelineSort(_ lhs: TimelineEvent, _ rhs: TimelineEvent) -> Bool {
        switch (lhs.date, rhs.date) {
        case let (.some(lhsDate), .some(rhsDate)):
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            break
        }

        let titleOrder = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
        if titleOrder != .orderedSame {
            return titleOrder == .orderedAscending
        }

        return lhs.id < rhs.id
    }

    nonisolated private static func recentTimelineSort(_ lhs: TimelineEvent, _ rhs: TimelineEvent) -> Bool {
        switch (lhs.date, rhs.date) {
        case let (.some(lhsDate), .some(rhsDate)):
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            break
        }

        let titleOrder = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
        if titleOrder != .orderedSame {
            return titleOrder == .orderedAscending
        }

        return lhs.id < rhs.id
    }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter
    }()

    private static let dayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("HH:mm")
        return formatter
    }()

    private static let calendar = Calendar.current
}

private enum TimelineSection {
    case recent
    case today
    case tomorrow
    case later
}

private struct LaterEventGroup: Identifiable {
    let title: String
    var events: [TimelineEvent]

    var id: String { title }
}

private struct TimelineEvent: Identifiable {
    enum Kind {
        case birthday
        case meeting
        case contactReminder
        case interaction

    }

    let id: String
    let kind: Kind
    let marker: String
    let title: String
    let subtitle: String?
    let date: Date?
}
