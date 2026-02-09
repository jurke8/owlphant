import Foundation

struct BirthdayValue: Hashable {
    let year: Int
    let month: Int?
    let day: Int?

    nonisolated init?(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: "-")
        switch parts.count {
        case 1:
            guard let year = Int(parts[0]), (1...9999).contains(year) else { return nil }
            self.year = year
            self.month = nil
            self.day = nil
        case 2:
            guard
                let year = Int(parts[0]),
                let month = Int(parts[1]),
                (1...9999).contains(year),
                (1...12).contains(month)
            else {
                return nil
            }
            self.year = year
            self.month = month
            self.day = nil
        case 3:
            let calendar = Calendar(identifier: .gregorian)
            guard
                let year = Int(parts[0]),
                let month = Int(parts[1]),
                let day = Int(parts[2]),
                (1...9999).contains(year),
                (1...12).contains(month),
                (1...31).contains(day),
                calendar.date(from: DateComponents(year: year, month: month, day: day)) != nil
            else {
                return nil
            }
            self.year = year
            self.month = month
            self.day = day
        default:
            return nil
        }
    }

    init(year: Int, month: Int?, day: Int?) {
        self.year = year
        self.month = month
        self.day = day
    }

    var rawValue: String {
        if let month, let day {
            return String(format: "%04d-%02d-%02d", year, month, day)
        }
        if let month {
            return String(format: "%04d-%02d", year, month)
        }
        return String(format: "%04d", year)
    }

    var isFullDate: Bool {
        month != nil && day != nil
    }

    var monthDay: DateComponents? {
        guard let month, let day else { return nil }
        return DateComponents(month: month, day: day)
    }

    var displayText: String {
        let calendar = Calendar(identifier: .gregorian)
        if let month, let day,
           let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) {
            return Self.fullDateFormatter.string(from: date)
        }

        if let month,
           let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) {
            return Self.monthYearFormatter.string(from: date)
        }

        return String(year)
    }
    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.setLocalizedDateFormatFromTemplate("MMMM d, yyyy")
        return formatter
    }()

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter
    }()
}
