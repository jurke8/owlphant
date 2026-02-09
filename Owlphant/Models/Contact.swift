import Foundation

enum RelationshipType: String, CaseIterable, Codable, Identifiable {
    case friend = "Friend"
    case dad = "Dad"
    case mom = "Mom"
    case daughter = "Daughter"
    case son = "Son"
    case parent = "Parent"
    case child = "Child"
    case wife = "Wife"
    case husband = "Husband"
    case partner = "Partner"
    case sibling = "Sibling"
    case colleague = "Colleague"
    case other = "Other"

    var id: String { rawValue }

    var reciprocal: RelationshipType {
        switch self {
        case .friend: .friend
        case .dad, .mom, .parent: .child
        case .son, .daughter, .child: .parent
        case .wife: .husband
        case .husband: .wife
        case .partner: .partner
        case .sibling: .sibling
        case .colleague: .colleague
        case .other: .other
        }
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
    var notes: String?
    var tags: [String]
    var relationships: [ContactRelationship]
    var updatedAt: TimeInterval

    var displayName: String {
        let combined = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
        return combined.isEmpty ? "Unnamed Contact" : combined
    }

    var initials: String {
        let first = firstName.first.map(String.init) ?? ""
        let last = lastName.first.map(String.init) ?? ""
        let merged = (first + last).uppercased()
        return merged.isEmpty ? "?" : merged
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
