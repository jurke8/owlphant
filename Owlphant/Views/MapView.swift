import MapKit
import SwiftUI

struct PeopleMapView: View {
    @StateObject private var viewModel = MapViewModel()

    var body: some View {
        NavigationStack {
            ScreenBackground {
                VStack(spacing: 14) {
                    SectionCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Map")
                                    .font(.system(size: 30, weight: .bold, design: .serif))
                                    .foregroundStyle(AppTheme.text)
                                Text("Tap a person on the map to open their details.")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(AppTheme.muted)
                            }
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(AppTheme.tint)
                            }
                        }
                    }

                    SectionCard {
                        if viewModel.pins.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("No mapped contacts yet")
                                    .font(.system(.headline, design: .rounded).weight(.semibold))
                                    .foregroundStyle(AppTheme.text)
                                Text("Add a living place to contacts and refresh to see them here.")
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(AppTheme.muted)
                            }
                        } else {
                            mapView
                                .frame(height: 460)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(AppTheme.stroke, lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 10)
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.reload() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(AppTheme.tint)
                    }
                }
            }
        }
        .task {
            await viewModel.reload()
        }
        .sheet(item: $viewModel.selectedContact) { contact in
            MapContactDetailsView(contact: contact)
        }
        .sheet(item: $viewModel.selectedGroup) { group in
            MapGroupedContactsView(group: group) { contact in
                viewModel.selectedGroup = nil
                viewModel.selectedContact = contact
            }
        }
        .alert("Map notice", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var mapView: some View {
        Map(position: $viewModel.cameraPosition, interactionModes: [.all]) {
            ForEach(viewModel.pins) { pin in
                Annotation("", coordinate: pin.coordinate, anchor: .bottom) {
                    mapPinView(pin)
                }
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
            MapPitchToggle()
        }
    }

    @ViewBuilder
    private func mapPinView(_ pin: ContactMapPin) -> some View {
        switch pin.kind {
        case let .single(contact):
            ContactMapAnnotationView(contact: contact)
                .onTapGesture {
                    viewModel.selectedContact = contact
                }
        case let .group(place, contacts):
            GroupMapAnnotationView(place: place, contacts: contacts)
                .onTapGesture {
                    viewModel.selectedGroup = ContactGroupSelection(
                        id: pin.id,
                        place: place,
                        contacts: contacts
                    )
                }
        }
    }
}

private struct ContactMapAnnotationView: View {
    let contact: Contact

    var body: some View {
        VStack(spacing: 6) {
            Group {
                if let photo = contact.photoDataBase64,
                   let data = Data(base64Encoded: photo),
                   let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Circle()
                        .fill(AppTheme.tint.opacity(0.16))
                        .overlay {
                            Text(contact.initials)
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundStyle(AppTheme.text)
                        }
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 2))

            Text(contact.displayName)
                .lineLimit(1)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.text)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppTheme.stroke, lineWidth: 1))
        }
    }
}

private struct GroupMapAnnotationView: View {
    let place: String
    let contacts: [Contact]

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(AppTheme.tint)
                    .frame(width: 42, height: 42)

                Text("+\(contacts.count)")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.white)
            }
            .overlay(Circle().stroke(Color.white, lineWidth: 2))

            Text(place)
                .lineLimit(1)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.text)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppTheme.stroke, lineWidth: 1))
        }
    }
}

private struct MapGroupedContactsView: View {
    let group: ContactGroupSelection
    let onOpenContact: (Contact) -> Void

    var body: some View {
        NavigationStack {
            ScreenBackground {
                ScrollView {
                    VStack(spacing: 12) {
                        SectionCard {
                            Text("\(group.contacts.count) contacts in this place")
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.text)
                            Text(group.place)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(AppTheme.muted)
                        }

                        ForEach(group.contacts) { contact in
                            SectionCard {
                                Button {
                                    onOpenContact(contact)
                                } label: {
                                    HStack(spacing: 10) {
                                        Group {
                                            if let photo = contact.photoDataBase64,
                                               let data = Data(base64Encoded: photo),
                                               let image = UIImage(data: data) {
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .scaledToFill()
                                            } else {
                                                Circle()
                                                    .fill(AppTheme.tint.opacity(0.16))
                                                    .overlay {
                                                        Text(contact.initials)
                                                            .font(.system(.caption, design: .rounded).weight(.bold))
                                                            .foregroundStyle(AppTheme.text)
                                                    }
                                            }
                                        }
                                        .frame(width: 42, height: 42)
                                        .clipShape(Circle())

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(contact.displayName)
                                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                                .foregroundStyle(AppTheme.text)
                                            if let nickname = contact.nickname, !nickname.isEmpty {
                                                Text("\"\(nickname)\"")
                                                    .font(.system(.subheadline, design: .rounded))
                                                    .foregroundStyle(AppTheme.muted)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(AppTheme.muted)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Same Place")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct MapContactDetailsView: View {
    let contact: Contact

    var body: some View {
        NavigationStack {
            ScreenBackground {
                ScrollView {
                    VStack(spacing: 12) {
                        SectionCard {
                            HStack(spacing: 12) {
                                avatar
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(contact.displayName)
                                        .font(.system(.title2, design: .serif).weight(.semibold))
                                        .foregroundStyle(AppTheme.text)
                                    if let nickname = contact.nickname, !nickname.isEmpty {
                                        Text("\"\(nickname)\"")
                                            .font(.system(.subheadline, design: .rounded))
                                            .foregroundStyle(AppTheme.muted)
                                    }
                                }
                                Spacer()
                            }
                        }

                        if let place = contact.placeOfLiving, !place.isEmpty {
                            SectionCard {
                                Text("Lives in")
                                    .font(.system(.caption, design: .rounded).weight(.medium))
                                    .textCase(.uppercase)
                                    .foregroundStyle(AppTheme.muted)
                                Text(place)
                                    .font(.system(.headline, design: .rounded).weight(.semibold))
                                    .foregroundStyle(AppTheme.text)
                            }
                        }

                        if let birthday = contact.birthday, !birthday.isEmpty {
                            SectionCard {
                                Text("Birthday")
                                    .font(.system(.caption, design: .rounded).weight(.medium))
                                    .textCase(.uppercase)
                                    .foregroundStyle(AppTheme.muted)
                                Text(birthday)
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(AppTheme.text)
                            }
                        }

                        if let company = contact.company, !company.isEmpty {
                            SectionCard {
                                Text("Work")
                                    .font(.system(.caption, design: .rounded).weight(.medium))
                                    .textCase(.uppercase)
                                    .foregroundStyle(AppTheme.muted)
                                Text(company)
                                    .font(.system(.headline, design: .rounded).weight(.semibold))
                                    .foregroundStyle(AppTheme.text)
                                if let position = contact.workPosition, !position.isEmpty {
                                    Text(position)
                                        .font(.system(.body, design: .rounded))
                                        .foregroundStyle(AppTheme.muted)
                                }
                            }
                        }

                        if !contact.phones.isEmpty || !contact.emails.isEmpty {
                            SectionCard {
                                if !contact.phones.isEmpty {
                                    Text("Phones")
                                        .font(.system(.caption, design: .rounded).weight(.medium))
                                        .textCase(.uppercase)
                                        .foregroundStyle(AppTheme.muted)
                                    ForEach(contact.phones, id: \.self) { phone in
                                        Text(phone)
                                            .font(.system(.body, design: .rounded))
                                            .foregroundStyle(AppTheme.text)
                                    }
                                }

                                if !contact.emails.isEmpty {
                                    Text("Emails")
                                        .font(.system(.caption, design: .rounded).weight(.medium))
                                        .textCase(.uppercase)
                                        .foregroundStyle(AppTheme.muted)
                                        .padding(.top, contact.phones.isEmpty ? 0 : 6)
                                    ForEach(contact.emails, id: \.self) { email in
                                        Text(email)
                                            .font(.system(.body, design: .rounded))
                                            .foregroundStyle(AppTheme.text)
                                    }
                                }
                            }
                        }

                        if let notes = contact.notes, !notes.isEmpty {
                            SectionCard {
                                Text("Notes")
                                    .font(.system(.caption, design: .rounded).weight(.medium))
                                    .textCase(.uppercase)
                                    .foregroundStyle(AppTheme.muted)
                                Text(notes)
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(AppTheme.text)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Contact")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let photo = contact.photoDataBase64,
           let data = Data(base64Encoded: photo),
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 58, height: 58)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(AppTheme.tint.opacity(0.16))
                .frame(width: 58, height: 58)
                .overlay {
                    Text(contact.initials)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.text)
                }
        }
    }
}
