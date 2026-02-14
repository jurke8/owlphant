import Foundation

enum RelationshipType: String, CaseIterable, Codable, Identifiable {
    case friend = "Friend"
    case colleague = "Colleague"
    case acquaintance = "Acquaintance"
    case parent = "Parent"
    case child = "Child"
    case sibling = "Sibling"
    case spouse = "Spouse"
    case partner = "Partner"
    case other = "Other"

    var id: String { rawValue }

    var reciprocal: RelationshipType {
        switch self {
        case .friend: .friend
        case .colleague: .colleague
        case .acquaintance: .acquaintance
        case .parent: .child
        case .child: .parent
        case .sibling: .sibling
        case .spouse: .spouse
        case .partner: .partner
        case .other: .other
        }
    }

    var sortRank: Int {
        switch self {
        case .friend: 0
        case .colleague: 1
        case .acquaintance: 2
        case .parent: 3
        case .child: 4
        case .sibling: 5
        case .spouse: 6
        case .partner: 7
        case .other: 8
        }
    }

    var localizedTitle: String {
        switch self {
        case .friend:
            return L10n.tr("relationship.friend")
        case .colleague:
            return L10n.tr("relationship.colleague")
        case .acquaintance:
            return L10n.tr("relationship.acquaintance")
        case .parent:
            return L10n.tr("relationship.parent")
        case .child:
            return L10n.tr("relationship.child")
        case .sibling:
            return L10n.tr("relationship.sibling")
        case .spouse:
            return L10n.tr("relationship.spouse")
        case .partner:
            return L10n.tr("relationship.partner")
        case .other:
            return L10n.tr("relationship.other")
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw.lowercased() {
        case "friend": self = .friend
        case "parent", "dad", "mom": self = .parent
        case "child", "daughter", "son": self = .child
        case "spouse", "wife", "husband": self = .spouse
        case "acquaintance": self = .acquaintance
        case "partner": self = .partner
        case "sibling": self = .sibling
        case "colleague": self = .colleague
        case "other": self = .other
        default: self = .acquaintance
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct ContactRelationship: Codable, Hashable, Identifiable {
    var contactId: UUID
    var type: RelationshipType

    var id: String { "\(contactId.uuidString)-\(type.rawValue)" }
}

struct ContactInteraction: Codable, Hashable, Identifiable {
    var id: UUID
    var date: TimeInterval
    var note: String
}

struct Contact: Codable, Identifiable, Hashable {
    var id: UUID
    var firstName: String
    var lastName: String
    var nickname: String?
    var birthday: String?
    var photoDataBase64: String?
    var placeOfBirth: String?
    var placeOfLiving: String?
    var company: String?
    var workPosition: String?
    var phones: [String]
    var emails: [String]
    var facebook: [String]? = nil
    var linkedin: [String]? = nil
    var instagram: [String]? = nil
    var x: [String]? = nil
    var notes: String?
    var tags: [String]
    var relationships: [ContactRelationship]
    var interactions: [ContactInteraction] = []
    var coffeeReminderAt: TimeInterval?
    var stayInTouchEveryDays: Int?
    var updatedAt: TimeInterval

    var groups: [String] {
        get { tags }
        set { tags = newValue }
    }

    var displayName: String {
        let combined = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
        if !combined.isEmpty {
            return combined
        }

        let nick = nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return nick.isEmpty ? L10n.tr("contacts.unnamed") : nick
    }

    var initials: String {
        let first = firstName.first.map(String.init) ?? ""
        let last = lastName.first.map(String.init) ?? ""
        let merged = (first + last).uppercased()
        if !merged.isEmpty {
            return merged
        }

        let nickInitial = nickname?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .first
            .map { String($0).uppercased() } ?? ""
        return nickInitial.isEmpty ? "?" : nickInitial
    }
}

extension Contact {
    static let sampleSeed: [Contact] = {
        let ivanId = UUID(uuidString: "1F7194D1-387D-4698-9B9C-B7E0C8F46BA9")!
        let anjaId = UUID(uuidString: "D98A105B-ECD0-4F6A-BA53-D2AD1D6B8465")!

        return [
            Contact(
                id: ivanId,
                firstName: "Ivan",
                lastName: "Juric",
                nickname: "Jurke",
                birthday: "1989-04-22",
                photoDataBase64: nil,
                placeOfBirth: "Osijek, Croatia",
                placeOfLiving: "Osijek, Croatia",
                company: "Slavonia Tech",
                workPosition: "Software Engineer",
                phones: ["+385 91 234 5678"],
                emails: ["ivan.juric@example.com"],
                notes: "Husband of Anja. Loves weekend cycling by the Drava and follows NK Osijek.",
                tags: ["family", "tech", "cycling"],
                relationships: [
                    ContactRelationship(contactId: anjaId, type: .spouse)
                ],
                interactions: [
                    ContactInteraction(
                        id: UUID(uuidString: "3443AD55-95D4-42F9-A963-0CF089B8F03E")!,
                        date: Date().addingTimeInterval(-60 * 60 * 24 * 4).timeIntervalSince1970,
                        note: "Had coffee by the Drava and talked about spring travel plans."
                    )
                ],
                coffeeReminderAt: nil,
                stayInTouchEveryDays: nil,
                updatedAt: Date().timeIntervalSince1970
            ),
            Contact(
                id: anjaId,
                firstName: "Anja",
                lastName: "Juric",
                nickname: "Njanja",
                birthday: "1991-09-10",
                photoDataBase64: nil,
                placeOfBirth: "Zagreb, Croatia",
                placeOfLiving: "Zagreb, Croatia",
                company: "Zagreb Design Studio",
                workPosition: "Interior Designer",
                phones: ["+385 98 345 6789"],
                emails: ["anja.juric@example.com"],
                notes: "Wife of Ivan. Enjoys modern art exhibitions and short city-break trips.",
                tags: ["family", "design", "art"],
                relationships: [
                    ContactRelationship(contactId: ivanId, type: .spouse)
                ],
                interactions: [
                    ContactInteraction(
                        id: UUID(uuidString: "90E98D2E-9B6B-43E0-A23D-B6AF3A7DFE32")!,
                        date: Date().addingTimeInterval(-60 * 60 * 24 * 2).timeIntervalSince1970,
                        note: "Called about her Zagreb exhibition opening next month."
                    )
                ],
                coffeeReminderAt: nil,
                stayInTouchEveryDays: nil,
                updatedAt: Date().timeIntervalSince1970 - 1
            ),
        ]
    }()
}
