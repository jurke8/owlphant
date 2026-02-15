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

struct ContactCustomField: Codable, Hashable, Identifiable {
    var id: UUID
    var label: String
    var value: String
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
    var customFields: [ContactCustomField]? = nil
    var relationships: [ContactRelationship]
    var interactions: [ContactInteraction] = []
    var coffeeReminderAt: TimeInterval?
    var stayInTouchEveryDays: Int?
    var updatedAt: TimeInterval

    var groups: [String] {
        get { tags }
        set { tags = newValue }
    }

    var resolvedCustomFields: [ContactCustomField] {
        customFields ?? []
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
        let markoId = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let ivaId = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
        let petraId = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let nikolaId = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!
        let majaId = UUID(uuidString: "55555555-5555-4555-8555-555555555555")!
        let anteId = UUID(uuidString: "66666666-6666-4666-8666-666666666666")!
        let lucijaId = UUID(uuidString: "77777777-7777-4777-8777-777777777777")!
        let stjepanId = UUID(uuidString: "88888888-8888-4888-8888-888888888888")!
        let teaId = UUID(uuidString: "99999999-9999-4999-8999-999999999999")!
        let josipId = UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA")!
        let marinaId = UUID(uuidString: "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB")!
        let domagojId = UUID(uuidString: "CCCCCCCC-CCCC-4CCC-8CCC-CCCCCCCCCCCC")!
        let leonaId = UUID(uuidString: "DDDDDDDD-DDDD-4DDD-8DDD-DDDDDDDDDDDD")!
        let kresimirId = UUID(uuidString: "EEEEEEEE-EEEE-4EEE-8EEE-EEEEEEEEEEEE")!
        let hanaId = UUID(uuidString: "FFFFFFFF-FFFF-4FFF-8FFF-FFFFFFFFFFFF")!
        let saraId = UUID(uuidString: "12121212-3434-4A4A-8B8B-565656565656")!
        let filipId = UUID(uuidString: "13131313-2424-4C4C-8D8D-575757575757")!
        let mateaId = UUID(uuidString: "14141414-2525-4E4E-8F8F-585858585858")!
        let rokId = UUID(uuidString: "15151515-2626-4A5A-8B6B-595959595959")!
        let anaId = UUID(uuidString: "16161616-2727-4C6C-8D7D-606060606060")!

        let now = Date().timeIntervalSince1970

        return [
            Contact(
                id: markoId,
                firstName: "Marko",
                lastName: "Horvat",
                nickname: "Maki",
                birthday: "1988-03-14",
                photoDataBase64: nil,
                placeOfBirth: "Osijek, Croatia",
                placeOfLiving: "Zagreb, Croatia",
                company: "Adriatic Soft",
                workPosition: "Product Manager",
                phones: ["+385 91 210 3456"],
                emails: ["marko.horvat@example.com"],
                notes: "Planning summer road trip across Dalmatia.",
                tags: ["family", "business", "travel"],
                relationships: [
                    ContactRelationship(contactId: ivaId, type: .spouse)
                ],
                interactions: [
                    ContactInteraction(
                        id: UUID(uuidString: "A1B2C3D4-E5F6-4A1B-8C9D-0E1F2A3B4C5D")!,
                        date: now - 60 * 60 * 24 * 3,
                        note: "Lunch in Zagreb and discussed quarterly goals."
                    )
                ],
                coffeeReminderAt: nil,
                stayInTouchEveryDays: nil,
                updatedAt: now
            ),
            Contact(
                id: ivaId,
                firstName: "Iva",
                lastName: "Horvat",
                nickname: "Ivi",
                birthday: "1990-11-08",
                photoDataBase64: nil,
                placeOfBirth: "Zagreb, Croatia",
                placeOfLiving: "Zagreb, Croatia",
                company: "Blue Frame Studio",
                workPosition: "Interior Designer",
                phones: ["+385 98 220 1188"],
                emails: ["iva.horvat@example.com"],
                notes: "Collects Croatian ceramics and hosts design workshops.",
                tags: ["family", "design", "art"],
                relationships: [
                    ContactRelationship(contactId: markoId, type: .spouse)
                ],
                interactions: [
                    ContactInteraction(
                        id: UUID(uuidString: "B1C2D3E4-F5A6-4B1C-8D9E-1F2A3B4C5D6E")!,
                        date: now - 60 * 60 * 24 * 2,
                        note: "Called about a new showroom opening in Zagreb."
                    )
                ],
                coffeeReminderAt: nil,
                stayInTouchEveryDays: nil,
                updatedAt: now - 1
            ),
            Contact(
                id: petraId,
                firstName: "Petra",
                lastName: "Kovacevic",
                nickname: nil,
                birthday: "1993-05-19",
                photoDataBase64: nil,
                placeOfBirth: "Rijeka, Croatia",
                placeOfLiving: "Rijeka, Croatia",
                company: "Kvarner Media",
                workPosition: "Content Strategist",
                phones: ["+385 95 301 1122"],
                emails: ["petra.kovacevic@example.com"],
                notes: "Often in Opatija for weekend walks.",
                tags: ["media", "friends"],
                relationships: [
                    ContactRelationship(contactId: nikolaId, type: .sibling)
                ],
                interactions: [],
                coffeeReminderAt: nil,
                stayInTouchEveryDays: nil,
                updatedAt: now - 2
            ),
            Contact(
                id: nikolaId,
                firstName: "Nikola",
                lastName: "Kovacevic",
                nickname: "Niko",
                birthday: "1986-01-30",
                photoDataBase64: nil,
                placeOfBirth: "Rijeka, Croatia",
                placeOfLiving: "Pula, Croatia",
                company: "Istra Build",
                workPosition: "Civil Engineer",
                phones: ["+385 91 302 2211"],
                emails: ["nikola.kovacevic@example.com"],
                notes: "Coordinates coastal infrastructure projects.",
                tags: ["engineering", "family"],
                relationships: [
                    ContactRelationship(contactId: petraId, type: .sibling)
                ],
                interactions: [],
                coffeeReminderAt: nil,
                stayInTouchEveryDays: nil,
                updatedAt: now - 3
            ),
            Contact(
                id: majaId,
                firstName: "Maja",
                lastName: "Babic",
                nickname: nil,
                birthday: "1994-07-12",
                photoDataBase64: nil,
                placeOfBirth: "Split, Croatia",
                placeOfLiving: "Split, Croatia",
                company: "Dalma Events",
                workPosition: "Event Coordinator",
                phones: ["+385 97 303 3344"],
                emails: ["maja.babic@example.com"],
                notes: "Organizes local culture festivals.",
                tags: ["events", "culture"],
                relationships: [],
                interactions: [],
                coffeeReminderAt: nil,
                stayInTouchEveryDays: nil,
                updatedAt: now - 4
            ),
            Contact(
                id: anteId,
                firstName: "Ante",
                lastName: "Peric",
                nickname: nil,
                birthday: "1985-09-22",
                photoDataBase64: nil,
                placeOfBirth: "Sibenik, Croatia",
                placeOfLiving: "Zadar, Croatia",
                company: "North Coast Logistics",
                workPosition: "Operations Lead",
                phones: ["+385 98 304 4455"],
                emails: ["ante.peric@example.com"],
                notes: "Handles seasonal shipping routes.",
                tags: ["work", "logistics"],
                relationships: [
                    ContactRelationship(contactId: lucijaId, type: .colleague)
                ],
                interactions: [
                    ContactInteraction(
                        id: UUID(uuidString: "C1D2E3F4-A5B6-4C1D-8E9F-2A3B4C5D6E7F")!,
                        date: now - 60 * 60 * 24 * 8,
                        note: "Reviewed shipping timelines for the Zadar warehouse."
                    )
                ],
                coffeeReminderAt: nil,
                stayInTouchEveryDays: nil,
                updatedAt: now - 5
            ),
            Contact(
                id: lucijaId,
                firstName: "Lucija",
                lastName: "Rogic",
                nickname: "Luce",
                birthday: "1992-12-03",
                photoDataBase64: nil,
                placeOfBirth: "Zadar, Croatia",
                placeOfLiving: "Sibenik, Croatia",
                company: "North Coast Logistics",
                workPosition: "Procurement Specialist",
                phones: ["+385 95 305 5566"],
                emails: ["lucija.rogic@example.com"],
                notes: "Enjoys weekend sailing trips near Kornati.",
                tags: ["work", "sea"],
                relationships: [
                    ContactRelationship(contactId: anteId, type: .colleague)
                ],
                interactions: [],
                coffeeReminderAt: nil,
                stayInTouchEveryDays: nil,
                updatedAt: now - 6
            ),
            Contact(
                id: stjepanId,
                firstName: "Stjepan",
                lastName: "Novak",
                nickname: nil,
                birthday: "1979-02-17",
                photoDataBase64: nil,
                placeOfBirth: "Varazdin, Croatia",
                placeOfLiving: "Varazdin, Croatia",
                company: "Novak Auto",
                workPosition: "Business Owner",
                phones: ["+385 91 306 6677"],
                emails: ["stjepan.novak@example.com"],
                notes: "Running a family auto shop for two decades.",
                tags: ["business", "cars"],
                relationships: [],
                interactions: [],
                coffeeReminderAt: nil,
                stayInTouchEveryDays: nil,
                updatedAt: now - 7
            ),
            Contact(
                id: teaId,
                firstName: "Tea",
                lastName: "Matic",
                nickname: nil,
                birthday: "1996-06-01",
                photoDataBase64: nil,
                placeOfBirth: "Dubrovnik, Croatia",
                placeOfLiving: "Dubrovnik, Croatia",
                company: "South Shore Travel",
                workPosition: "Tour Manager",
                phones: ["+385 98 307 7788"],
                emails: ["tea.matic@example.com"],
                notes: "Guides city tours in multiple languages.",
                tags: ["travel", "friends"],
                relationships: [
                    ContactRelationship(contactId: josipId, type: .partner)
                ],
                interactions: [
                    ContactInteraction(
                        id: UUID(uuidString: "D1E2F3A4-B5C6-4D1E-8F9A-3B4C5D6E7F80")!,
                        date: now - 60 * 60 * 24 * 5,
                        note: "Met after a guided walk along Dubrovnik walls."
                    )
                ],
                coffeeReminderAt: nil,
                stayInTouchEveryDays: nil,
                updatedAt: now - 8
            ),
            Contact(
                id: josipId,
                firstName: "Josip",
                lastName: "Prgomet",
                nickname: nil,
                birthday: "1994-10-27",
                photoDataBase64: nil,
                placeOfBirth: "Makarska, Croatia",
                placeOfLiving: "Makarska, Croatia",
                company: "Biokovo Trails",
                workPosition: "Outdoor Guide",
                phones: ["+385 97 308 8899"],
                emails: ["josip.prgomet@example.com"],
                notes: "Trains for mountain trail races.",
                tags: ["outdoors", "sport"],
                relationships: [
                    ContactRelationship(contactId: teaId, type: .partner)
                ],
                interactions: [],
                coffeeReminderAt: nil,
                stayInTouchEveryDays: nil,
                updatedAt: now - 9
            ),
            Contact(
                id: marinaId,
                firstName: "Marina",
                lastName: "Filipovic",
                nickname: nil,
                birthday: "1975-04-04",
                photoDataBase64: nil,
                placeOfBirth: "Karlovac, Croatia",
                placeOfLiving: "Karlovac, Croatia",
                company: "Karlovac Gymnasium",
                workPosition: "Teacher",
                phones: ["+385 95 309 9900"],
                emails: ["marina.filipovic@example.com"],
                notes: "Coordinates school debate club.",
                tags: ["education", "family"],
                relationships: [
                    ContactRelationship(contactId: domagojId, type: .parent)
                ],
                interactions: [],
                coffeeReminderAt: nil,
                stayInTouchEveryDays: nil,
                updatedAt: now - 10
            ),
            Contact(
                id: domagojId,
                firstName: "Domagoj",
                lastName: "Filipovic",
                nickname: "Dodo",
                birthday: "2001-08-15",
                photoDataBase64: nil,
                placeOfBirth: "Karlovac, Croatia",
                placeOfLiving: "Samobor, Croatia",
                company: "Freelance",
                workPosition: "Video Editor",
                phones: ["+385 91 310 1010"],
                emails: ["domagoj.filipovic@example.com"],
                notes: "Works on travel vlogs and short documentaries.",
                tags: ["creative", "family"],
                relationships: [
                    ContactRelationship(contactId: marinaId, type: .child)
                ],
                interactions: [],
                coffeeReminderAt: nil,
                stayInTouchEveryDays: nil,
                updatedAt: now - 11
            ),
            Contact(
                id: leonaId,
                firstName: "Leona",
                lastName: "Sekulic",
                nickname: nil,
                birthday: "1997-01-09",
                photoDataBase64: nil,
                placeOfBirth: "Pula, Croatia",
                placeOfLiving: "Rovinj, Croatia",
                company: "Istra Health",
                workPosition: "Physiotherapist",
                phones: ["+385 98 311 1212"],
                emails: ["leona.sekulic@example.com"],
                notes: "Enjoys sea kayaking around Istria.",
                tags: ["health", "friends"],
                relationships: [],
                interactions: [],
                coffeeReminderAt: nil,
                stayInTouchEveryDays: nil,
                updatedAt: now - 12
            ),
            Contact(
                id: kresimirId,
                firstName: "Kresimir",
                lastName: "Lukic",
                nickname: nil,
                birthday: "1982-11-21",
                photoDataBase64: nil,
                placeOfBirth: "Slavonski Brod, Croatia",
                placeOfLiving: "Slavonski Brod, Croatia",
                company: "Sava Metal",
                workPosition: "Plant Supervisor",
                phones: ["+385 97 312 1313"],
                emails: ["kresimir.lukic@example.com"],
                notes: "Leads production upgrades this year.",
                tags: ["industry", "work"],
                relationships: [],
                interactions: [],
                coffeeReminderAt: nil,
                stayInTouchEveryDays: nil,
                updatedAt: now - 13
            ),
            Contact(
                id: hanaId,
                firstName: "Hana",
                lastName: "Zoric",
                nickname: nil,
                birthday: "1995-03-26",
                photoDataBase64: nil,
                placeOfBirth: "Cakovec, Croatia",
                placeOfLiving: "Cakovec, Croatia",
                company: "Meimurje Finance",
                workPosition: "Accountant",
                phones: ["+385 95 313 1414"],
                emails: ["hana.zoric@example.com"],
                notes: "Plans a pottery course this spring.",
                tags: ["finance", "friends"],
                relationships: [
                    ContactRelationship(contactId: saraId, type: .friend)
                ],
                interactions: [],
                coffeeReminderAt: nil,
                stayInTouchEveryDays: nil,
                updatedAt: now - 14
            ),
            Contact(
                id: saraId,
                firstName: "Sara",
                lastName: "Brkic",
                nickname: nil,
                birthday: "1995-12-14",
                photoDataBase64: nil,
                placeOfBirth: "Bjelovar, Croatia",
                placeOfLiving: "Bjelovar, Croatia",
                company: "Bjelovar Clinic",
                workPosition: "Nurse",
                phones: ["+385 91 314 1515"],
                emails: ["sara.brkic@example.com"],
                notes: "Volunteers at local first-aid workshops.",
                tags: ["health", "community"],
                relationships: [
                    ContactRelationship(contactId: hanaId, type: .friend)
                ],
                interactions: [],
                coffeeReminderAt: nil,
                stayInTouchEveryDays: nil,
                updatedAt: now - 15
            ),
            Contact(
                id: filipId,
                firstName: "Filip",
                lastName: "Jelavic",
                nickname: nil,
                birthday: "1998-09-05",
                photoDataBase64: nil,
                placeOfBirth: "Vukovar, Croatia",
                placeOfLiving: "Vukovar, Croatia",
                company: "Danube Analytics",
                workPosition: "Data Analyst",
                phones: ["+385 98 315 1616"],
                emails: ["filip.jelavic@example.com"],
                notes: "Tracks tourism data along the Danube.",
                tags: ["data", "family"],
                relationships: [
                    ContactRelationship(contactId: mateaId, type: .sibling)
                ],
                interactions: [
                    ContactInteraction(
                        id: UUID(uuidString: "E1F2A3B4-C5D6-4E1F-8A9B-4C5D6E7F8091")!,
                        date: now - 60 * 60 * 24 * 6,
                        note: "Shared dashboard updates from the latest report."
                    )
                ],
                coffeeReminderAt: nil,
                stayInTouchEveryDays: nil,
                updatedAt: now - 16
            ),
            Contact(
                id: mateaId,
                firstName: "Matea",
                lastName: "Jelavic",
                nickname: nil,
                birthday: "2000-02-11",
                photoDataBase64: nil,
                placeOfBirth: "Vukovar, Croatia",
                placeOfLiving: "Osijek, Croatia",
                company: "UniLab",
                workPosition: "Research Assistant",
                phones: ["+385 97 316 1717"],
                emails: ["matea.jelavic@example.com"],
                notes: "Working on urban ecology projects.",
                tags: ["science", "family"],
                relationships: [
                    ContactRelationship(contactId: filipId, type: .sibling)
                ],
                interactions: [],
                coffeeReminderAt: nil,
                stayInTouchEveryDays: nil,
                updatedAt: now - 17
            ),
            Contact(
                id: rokId,
                firstName: "Rok",
                lastName: "Milic",
                nickname: nil,
                birthday: "2004-07-03",
                photoDataBase64: nil,
                placeOfBirth: "Koprivnica, Croatia",
                placeOfLiving: "Koprivnica, Croatia",
                company: "North Bike",
                workPosition: "Sales Associate",
                phones: ["+385 95 317 1818"],
                emails: ["rok.milic@example.com"],
                notes: "Training for local cycling races.",
                tags: ["sport", "family"],
                relationships: [
                    ContactRelationship(contactId: anaId, type: .child)
                ],
                interactions: [],
                coffeeReminderAt: nil,
                stayInTouchEveryDays: nil,
                updatedAt: now - 18
            ),
            Contact(
                id: anaId,
                firstName: "Ana",
                lastName: "Milic",
                nickname: nil,
                birthday: "1978-06-18",
                photoDataBase64: nil,
                placeOfBirth: "Pozega, Croatia",
                placeOfLiving: "Sisak, Croatia",
                company: "City Library Sisak",
                workPosition: "Librarian",
                phones: ["+385 91 318 1919"],
                emails: ["ana.milic@example.com"],
                notes: "Runs monthly reading circles.",
                tags: ["family", "community"],
                relationships: [
                    ContactRelationship(contactId: rokId, type: .parent)
                ],
                interactions: [
                    ContactInteraction(
                        id: UUID(uuidString: "F1A2B3C4-D5E6-4F1A-8B9C-5D6E7F8091A2")!,
                        date: now - 60 * 60 * 24,
                        note: "Stopped by the library for a quick catch-up."
                    )
                ],
                coffeeReminderAt: nil,
                stayInTouchEveryDays: nil,
                updatedAt: now - 19
            ),
        ]
    }()
}
