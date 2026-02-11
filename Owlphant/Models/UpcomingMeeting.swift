import Foundation

struct UpcomingMeeting: Identifiable, Hashable {
    let id: String
    let title: String
    let startDate: Date
    let location: String?
    let calendarName: String?
}
