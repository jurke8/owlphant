import Combine
import CoreLocation
import MapKit
import SwiftUI

enum ContactMapPinKind {
    case single(Contact)
    case group(place: String, contacts: [Contact])
}

struct ContactMapPin: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let kind: ContactMapPinKind

    var sortLabel: String {
        switch kind {
        case let .single(contact):
            return contact.displayName
        case let .group(place: place, contacts: contacts):
            _ = contacts.count
            return place
        }
    }
}

struct ContactGroupSelection: Identifiable {
    let id: String
    let place: String
    let contacts: [Contact]
}

@MainActor
final class MapViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var pins: [ContactMapPin] = []
    @Published var cameraPosition: MapCameraPosition = .automatic
    @Published var selectedContact: Contact?
    @Published var selectedGroup: ContactGroupSelection?
    @Published var errorMessage: String?

    private let store = EncryptedContactsStore()
    private var locationCache: [String: CLLocationCoordinate2D] = [:]

    func reload() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let contacts = try await store.loadContacts()
            let validContacts = contacts.compactMap { contact -> (Contact, String, String)? in
                guard let rawPlace = contact.placeOfLiving?.trimmingCharacters(in: .whitespacesAndNewlines), !rawPlace.isEmpty else {
                    return nil
                }
                return (contact, rawPlace, normalizePlace(rawPlace))
            }

            var groupedByPlace: [String: (displayPlace: String, contacts: [Contact])] = [:]
            for (contact, displayPlace, key) in validContacts {
                if groupedByPlace[key] == nil {
                    groupedByPlace[key] = (displayPlace, [contact])
                } else {
                    groupedByPlace[key]?.contacts.append(contact)
                }
            }

            var resolvedPins: [ContactMapPin] = []
            for (key, group) in groupedByPlace {
                let place = group.displayPlace

                if let cached = locationCache[place] {
                    resolvedPins.append(pin(for: group.contacts, place: place, groupKey: key, coordinate: cached))
                    continue
                }

                if let coordinate = await geocode(place: place) {
                    locationCache[place] = coordinate
                    resolvedPins.append(pin(for: group.contacts, place: place, groupKey: key, coordinate: coordinate))
                }
            }

            pins = resolvedPins.sorted { $0.sortLabel < $1.sortLabel }
            updateCameraPosition()

            if !validContacts.isEmpty && pins.isEmpty {
                errorMessage = "Could not map saved living places yet. Try again in a moment."
            }
        } catch {
            errorMessage = "Could not load contacts for map view."
        }
    }

    private func geocode(place: String) async -> CLLocationCoordinate2D? {
        do {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = place
            request.resultTypes = .address

            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.first?.location.coordinate
        } catch {
            return nil
        }
    }

    private func pin(for contacts: [Contact], place: String, groupKey: String, coordinate: CLLocationCoordinate2D) -> ContactMapPin {
        if contacts.count == 1, let contact = contacts.first {
            return ContactMapPin(
                id: contact.id.uuidString,
                coordinate: coordinate,
                kind: .single(contact)
            )
        }

        return ContactMapPin(
            id: "group-\(groupKey)",
            coordinate: coordinate,
            kind: .group(place: place, contacts: contacts.sorted { $0.displayName < $1.displayName })
        )
    }

    private func normalizePlace(_ place: String) -> String {
        place
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func updateCameraPosition() {
        guard !pins.isEmpty else {
            cameraPosition = .automatic
            return
        }

        if pins.count == 1, let only = pins.first {
            let region = MKCoordinateRegion(
                center: only.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)
            )
            cameraPosition = .region(region)
            return
        }

        let latitudes = pins.map { $0.coordinate.latitude }
        let longitudes = pins.map { $0.coordinate.longitude }

        guard let minLat = latitudes.min(),
              let maxLat = latitudes.max(),
              let minLon = longitudes.min(),
              let maxLon = longitudes.max() else {
            cameraPosition = .automatic
            return
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let latDelta = max(0.35, (maxLat - minLat) * 1.6)
        let lonDelta = max(0.35, (maxLon - minLon) * 1.6)

        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )

        cameraPosition = .region(region)
    }
}
