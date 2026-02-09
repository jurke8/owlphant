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
    var updatedAt: TimeInterval

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
    static let sampleSeed: [Contact] = [
        Contact(
            id: UUID(),
            firstName: "Mina",
            lastName: "Park",
            nickname: "Mina P",
            birthday: "1992-07-14",
            photoDataBase64: nil,
            placeOfBirth: "Seoul, South Korea",
            placeOfLiving: "1100 NW Glisan St, Portland, OR, United States",
            company: "Clayline Studio",
            workPosition: "Creative Director",
            phones: ["+1 555 201 4488"],
            emails: ["mina@example.com"],
            notes: "Loves ceramics, runs a community garden. Ask about her new studio.",
            tags: ["friend", "creative", "garden"],
            relationships: [],
            updatedAt: Date().timeIntervalSince1970
        ),
        Contact(
            id: UUID(),
            firstName: "Theo",
            lastName: "Diaz",
            nickname: "T",
            birthday: "1988-11-03",
            photoDataBase64: nil,
            placeOfBirth: "Bogota, Colombia",
            placeOfLiving: "401 Congress Ave, Austin, TX, United States",
            company: "Lumen Labs",
            workPosition: "Product Manager",
            phones: ["+1 555 908 1121"],
            emails: ["theo@example.com"],
            notes: "Brother. Anniversary on June 9. Favorite coffee: flat white.",
            tags: ["family", "anniversary"],
            relationships: [],
            updatedAt: Date().timeIntervalSince1970 - 1
        ),
    ]
}
