import MapKit
import SwiftUI

struct PeopleMapView: View {
    @StateObject private var viewModel = MapViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.pins.isEmpty && viewModel.userCoordinate == nil {
                    ScreenBackground {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.tr("map.empty.title"))
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.text)
                            Text(L10n.tr("map.empty.subtitle"))
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(AppTheme.muted)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                } else {
                    mapView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(L10n.tr("tab.map"))
            .navigationBarTitleDisplayMode(.inline)
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
        .alert(L10n.tr("map.alert.notice"), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(L10n.tr("common.ok"), role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var mapView: some View {
        Map(position: $viewModel.cameraPosition, interactionModes: [.all]) {
            UserAnnotation()

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
            MapUserLocationButton()
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                mapResetButton
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }

    private var mapResetButton: some View {
        Button {
            Task { await viewModel.reload() }
        } label: {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(AppTheme.tint)
                } else {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.text)
                }
            }
            .frame(width: 36, height: 36)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().stroke(AppTheme.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading)
        .accessibilityLabel(L10n.tr("map.accessibility.reset"))
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
                            Text(L10n.format("map.group.count", group.contacts.count))
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
            .navigationTitle(L10n.tr("map.samePlace.title"))
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
                                Text(L10n.tr("contacts.card.livesIn.label"))
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
                                Text(L10n.tr("contacts.form.birthday"))
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
                                Text(L10n.tr("contacts.card.work"))
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

                        if !contact.phones.isEmpty || !contact.emails.isEmpty || !(contact.facebook ?? []).isEmpty || !(contact.linkedin ?? []).isEmpty || !(contact.instagram ?? []).isEmpty || !(contact.x ?? []).isEmpty {
                            SectionCard {
                                Text(L10n.tr("contacts.form.section.channels"))
                                    .font(.system(.caption, design: .rounded).weight(.medium))
                                    .textCase(.uppercase)
                                    .foregroundStyle(AppTheme.muted)

                                if !contact.phones.isEmpty {
                                    Text(L10n.tr("contacts.card.phones"))
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
                                    Text(L10n.tr("contacts.card.emails"))
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

                                if let facebook = contact.facebook, !facebook.isEmpty {
                                    Text(L10n.tr("contacts.card.facebook"))
                                        .font(.system(.caption, design: .rounded).weight(.medium))
                                        .textCase(.uppercase)
                                        .foregroundStyle(AppTheme.muted)
                                        .padding(.top, (!contact.phones.isEmpty || !contact.emails.isEmpty) ? 6 : 0)
                                    ForEach(facebook, id: \.self) { handle in
                                        socialLinkView(handle, platform: .facebook)
                                    }
                                }

                                if let linkedin = contact.linkedin, !linkedin.isEmpty {
                                    Text(L10n.tr("contacts.card.linkedin"))
                                        .font(.system(.caption, design: .rounded).weight(.medium))
                                        .textCase(.uppercase)
                                        .foregroundStyle(AppTheme.muted)
                                        .padding(.top, 6)
                                    ForEach(linkedin, id: \.self) { handle in
                                        socialLinkView(handle, platform: .linkedin)
                                    }
                                }

                                if let instagram = contact.instagram, !instagram.isEmpty {
                                    Text(L10n.tr("contacts.card.instagram"))
                                        .font(.system(.caption, design: .rounded).weight(.medium))
                                        .textCase(.uppercase)
                                        .foregroundStyle(AppTheme.muted)
                                        .padding(.top, 6)
                                    ForEach(instagram, id: \.self) { handle in
                                        socialLinkView(handle, platform: .instagram)
                                    }
                                }

                                if let xHandles = contact.x, !xHandles.isEmpty {
                                    Text(L10n.tr("contacts.card.x"))
                                        .font(.system(.caption, design: .rounded).weight(.medium))
                                        .textCase(.uppercase)
                                        .foregroundStyle(AppTheme.muted)
                                        .padding(.top, 6)
                                    ForEach(xHandles, id: \.self) { handle in
                                        socialLinkView(handle, platform: .x)
                                    }
                                }
                            }
                        }

                        if let notes = contact.notes, !notes.isEmpty {
                            SectionCard {
                                Text(L10n.tr("contacts.form.notes"))
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
            .navigationTitle(L10n.tr("contacts.card.contact"))
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

    @ViewBuilder
    private func socialLinkView(_ rawValue: String, platform: SocialPlatform) -> some View {
        if let normalized = SocialLinkValidator.normalize(rawValue, platform: platform),
           let destination = URL(string: normalized) {
            Link(rawValue, destination: destination)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(AppTheme.tint)
                .lineLimit(1)
                .truncationMode(.middle)
        } else {
            Text(rawValue)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(AppTheme.text)
        }
    }
}
