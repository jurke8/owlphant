import Combine
import PhotosUI
import MapKit
import SwiftUI

struct ContactsView: View {
    @ObservedObject var viewModel: ContactsViewModel
    @State private var pendingDelete: Contact?

    var body: some View {
        NavigationStack {
            ScreenBackground {
                if !viewModel.isReady {
                    VStack(spacing: 14) {
                        Text(L10n.tr("contacts.title"))
                            .font(.system(size: 32, weight: .bold, design: .serif))
                            .foregroundStyle(AppTheme.text)
                        SectionCard {
                            Text(L10n.tr("contacts.setup.title"))
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.text)
                            Text(L10n.tr("contacts.setup.subtitle"))
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(AppTheme.muted)
                        }
                    }
                    .padding(24)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            header
                            if viewModel.filteredContacts.isEmpty {
                                SectionCard {
                                    Text(L10n.tr("contacts.empty.title"))
                                        .font(.system(.headline, design: .rounded).weight(.semibold))
                                        .foregroundStyle(AppTheme.text)
                                    Text(L10n.tr("contacts.empty.subtitle"))
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(AppTheme.muted)
                                }
                            } else {
                                ForEach(viewModel.filteredContacts) { contact in
                                    ContactCardView(
                                        contact: contact,
                                        relationshipLabel: { id in viewModel.relationshipTargetName(id) },
                                        onRelationshipTap: { relationship in
                                            viewModel.startEdit(contact)
                                            viewModel.editRelationship(relationship)
                                        },
                                        onEdit: { viewModel.startEdit(contact) },
                                        onDelete: { pendingDelete = contact }
                                    )
                                }
                            }
                        }
                        .padding(20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle(L10n.tr("contacts.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.startCreate()
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(AppTheme.tint)
                    }
                }
            }
        }
        .task {
            if !viewModel.isReady {
                await viewModel.bootstrap()
            }
        }
        .sheet(isPresented: $viewModel.isPresentingForm) {
            ContactFormSheet(viewModel: viewModel)
        }
        .alert(L10n.tr("contacts.alert.delete.title"), isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button(L10n.tr("common.cancel"), role: .cancel) {
                pendingDelete = nil
            }
            Button(L10n.tr("common.delete"), role: .destructive) {
                if let pendingDelete {
                    Task { await viewModel.delete(pendingDelete) }
                }
                self.pendingDelete = nil
            }
        } message: {
            Text(L10n.tr("contacts.alert.delete.message"))
        }
        .alert(L10n.tr("common.notice"), isPresented: Binding(
            get: { !viewModel.isPresentingForm && viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(L10n.tr("common.ok"), role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.tr("contacts.header.subtitle"))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.muted)
                TextField(L10n.tr("contacts.header.searchPlaceholder"), text: $viewModel.query)
                    .textInputAutocapitalization(.never)
                    .appInputChrome()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(L10n.tr("contacts.filters.quick"))
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(AppTheme.muted)

                    if viewModel.activeGroupFilterCount > 0 {
                        Text(L10n.format("contacts.filters.activeCount", viewModel.activeGroupFilterCount))
                            .font(.system(.caption2, design: .rounded).weight(.bold))
                            .foregroundStyle(AppTheme.text)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.surfaceAlt)
                            .clipShape(Capsule())
                    }

                    if viewModel.activeGroupFilterCount > 0 {
                        Button(L10n.tr("common.clear")) {
                            viewModel.clearGroupFilters()
                        }
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(AppTheme.tint)
                        .buttonStyle(.plain)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            label: L10n.tr("contacts.filters.all"),
                            isSelected: viewModel.selectedGroups.isEmpty,
                            action: { viewModel.clearGroupFilters() }
                        )

                        ForEach(viewModel.availableGroups, id: \.self) { group in
                            FilterChip(
                                label: group,
                                isSelected: viewModel.isGroupSelected(group),
                                action: { viewModel.toggleGroupSelection(group) }
                            )
                        }
                    }
                }
            }

            HStack {
                Text(viewModel.sortField.localizedTitle)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                Spacer()
                Text(savedContactsText)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(AppTheme.muted)
            }

            HStack(spacing: 8) {
                Picker(L10n.tr("contacts.sort.field.title"), selection: $viewModel.sortField) {
                    ForEach(ContactSortField.allCases, id: \.self) { field in
                        Text(field.localizedTitle).tag(field)
                    }
                }
                .pickerStyle(.menu)
                .appInputChrome()

                Picker(L10n.tr("contacts.sort.direction.title"), selection: $viewModel.sortDirection) {
                    ForEach(ContactSortDirection.allCases, id: \.self) { direction in
                        Text(direction.localizedTitle).tag(direction)
                    }
                }
                .pickerStyle(.menu)
                .appInputChrome()
            }
        }
    }

    private var savedContactsText: String {
        L10n.format("contacts.header.savedCount", viewModel.filteredContacts.count)
    }
}

private struct ContactCardView: View {
    let contact: Contact
    let relationshipLabel: (UUID) -> String
    let onRelationshipTap: (ContactRelationship) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        SectionCard {
            HStack(alignment: .center, spacing: 10) {
                avatar
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.displayName)
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                    if let nickname = contact.nickname, !nickname.isEmpty {
                        Text("\"\(nickname)\"")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(AppTheme.muted)
                    }
                    if let company = contact.company, !company.isEmpty {
                        Text(contact.workPosition.map { "\($0) @ \(company)" } ?? company)
                            .font(.system(.footnote, design: .rounded).weight(.medium))
                            .foregroundStyle(AppTheme.muted)
                    }
                }
                Spacer()
                HStack(spacing: 8) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                    }
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                    }
                }
                .buttonStyle(.borderless)
                .foregroundStyle(AppTheme.muted)
            }

            if let birthday = contact.birthday, !birthday.isEmpty {
                Text("🎂 \(BirthdayValue(rawValue: birthday)?.displayText ?? birthday)")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(AppTheme.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.accent.opacity(0.18))
                    .clipShape(Capsule())
            }

            if let city = contact.placeOfLiving, !city.isEmpty {
                Text(L10n.format("contacts.card.livesIn", city))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.muted)
            }

            if !contact.groups.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(contact.groups.prefix(3), id: \.self) { group in
                        PillView(label: group)
                    }
                }
            }

            if let latestInteraction {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.tr("contacts.card.lastInteraction"))
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .textCase(.uppercase)
                        .foregroundStyle(AppTheme.muted)

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.tint)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(Self.interactionDateFormatter.string(from: Date(timeIntervalSince1970: latestInteraction.date)))
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.text)
                            Text(latestInteraction.note)
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(AppTheme.muted)
                                .lineLimit(2)
                        }
                    }
                }
            }

            if !contact.relationships.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L10n.tr("contacts.card.relationships"))
                            .font(.system(.caption, design: .rounded).weight(.medium))
                            .textCase(.uppercase)
                            .foregroundStyle(AppTheme.muted)
                        Spacer(minLength: 0)
                        Text("\(contact.relationships.count)")
                            .font(.system(.caption2, design: .rounded).weight(.semibold))
                            .foregroundStyle(AppTheme.muted)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(AppTheme.surfaceAlt.opacity(0.45))
                            .clipShape(Capsule())
                    }

                    ForEach(sortedRelationships) { relationship in
                        Button {
                            onRelationshipTap(relationship)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: relationship.type.symbolName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AppTheme.tint)
                                    .frame(width: 26, height: 26)
                                    .background(AppTheme.tint.opacity(0.12))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(relationshipLabel(relationship.contactId))
                                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                        .foregroundStyle(AppTheme.text)
                                        .lineLimit(1)
                                    Text(relationship.type.localizedTitle)
                                        .font(.system(.caption, design: .rounded).weight(.medium))
                                        .foregroundStyle(AppTheme.muted)
                                }

                                Spacer(minLength: 0)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(AppTheme.muted.opacity(0.8))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(AppTheme.surfaceAlt.opacity(0.45))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppTheme.stroke.opacity(0.45), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let base64 = contact.photoDataBase64,
           let data = Data(base64Encoded: base64),
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 46, height: 46)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(AppTheme.tint.opacity(0.14))
                .frame(width: 46, height: 46)
                .overlay {
                    Text(contact.initials)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(AppTheme.text)
                }
        }
    }

    private var sortedRelationships: [ContactRelationship] {
        contact.relationships.sorted { lhs, rhs in
            if lhs.type.sortRank == rhs.type.sortRank {
                return relationshipLabel(lhs.contactId) < relationshipLabel(rhs.contactId)
            }
            return lhs.type.sortRank < rhs.type.sortRank
        }
    }

    private var latestInteraction: ContactInteraction? {
        contact.interactions.max { lhs, rhs in
            lhs.date < rhs.date
        }
    }

    private static let interactionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("d MMM, HH:mm")
        return formatter
    }()
}

private extension RelationshipType {
    var symbolName: String {
        switch self {
        case .friend: "person.fill"
        case .parent: "figure.2.and.child.holdinghands"
        case .child: "figure.child"
        case .spouse: "heart.fill"
        case .acquaintance: "person.crop.circle.badge.questionmark"
        case .partner: "person.2.fill"
        case .sibling: "figure.2"
        case .colleague: "briefcase.fill"
        case .other: "tag.fill"
        }
    }
}

private struct ContactFormSheet: View {
    @ObservedObject var viewModel: ContactsViewModel
    @Environment(\.locale) private var locale
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var birthdayYear: Int? = 1990
    @State private var birthdayMonth: Int? = 1
    @State private var birthdayDay: Int?
    @State private var basicInfoExpanded = true
    @State private var locationExpanded = false
    @State private var workExpanded = false
    @State private var contactChannelsExpanded = false
    @State private var personalExpanded = false
    @State private var interactionsExpanded = false
    @State private var relationshipsExpanded = false
    @State private var remindersExpanded = false
    @State private var isCoffeeDatePickerPresented = false
    @State private var hasInteractedWithForm = false
    @State private var groupDraft = ""

    var body: some View {
        NavigationStack {
            ScreenBackground {
                ScrollView {
                    VStack(spacing: 12) {
                        SectionCard {
                            HStack {
                                Text(viewModel.selectedContactId == nil ? L10n.tr("contacts.form.addTitle") : L10n.tr("contacts.form.editTitle"))
                                    .font(.system(.title3, design: .rounded).weight(.semibold))
                                    .foregroundStyle(AppTheme.text)
                                Spacer()
                                Button(L10n.tr("common.cancel")) {
                                    viewModel.cancelForm()
                                }
                                .foregroundStyle(AppTheme.muted)
                            }
                        }

                        FormDisclosureSection(title: L10n.tr("contacts.form.section.basicInfo"), isExpanded: $basicInfoExpanded) {
                            photoRow
                            TextField(L10n.tr("contacts.form.firstName"), text: binding(\.firstName))
                                .appInputChrome()
                            TextField(L10n.tr("contacts.form.lastName"), text: binding(\.lastName))
                                .appInputChrome()

                            Text(L10n.tr("contacts.form.birthday"))
                                .font(.system(.footnote, design: .rounded).weight(.medium))
                                .foregroundStyle(AppTheme.muted)

                            HStack(spacing: 8) {
                                Picker(L10n.tr("contacts.form.birthdayDay"), selection: $birthdayDay) {
                                    Text("-").tag(Optional<Int>.none)
                                    ForEach(validDaysInSelectedMonth, id: \.self) { day in
                                        Text(String(day)).tag(Optional(day))
                                    }
                                }
                                .pickerStyle(.menu)
                                .disabled(birthdayMonth == nil)
                                .appInputChrome()
                                .frame(maxWidth: .infinity)

                                Picker(L10n.tr("contacts.form.birthdayMonth"), selection: $birthdayMonth) {
                                    Text("-").tag(Optional<Int>.none)
                                    ForEach(Array(Self.monthLabels.enumerated()), id: \.offset) { idx, label in
                                        Text(label)
                                            .lineLimit(1)
                                            .tag((idx + 1) as Int?)
                                    }
                                }
                                .pickerStyle(.menu)
                                .appInputChrome()
                                .frame(maxWidth: .infinity)

                                Picker(L10n.tr("contacts.form.birthdayYear"), selection: $birthdayYear) {
                                    Text("-").tag(Optional<Int>.none)
                                    ForEach(Self.yearOptions, id: \.self) { year in
                                        Text(String(year)).tag(Optional(year))
                                    }
                                }
                                .pickerStyle(.menu)
                                .appInputChrome()
                                .frame(maxWidth: .infinity)
                            }
                        }

                        FormDisclosureSection(title: L10n.tr("contacts.form.section.location"), isExpanded: $locationExpanded) {
                            CityAutocompleteField(title: L10n.tr("contacts.form.placeOfBirth"), text: binding(\.placeOfBirth))
                            AddressAutocompleteField(title: L10n.tr("contacts.form.placeOfLiving"), text: binding(\.placeOfLiving))
                        }

                        FormDisclosureSection(title: L10n.tr("contacts.form.section.work"), isExpanded: $workExpanded) {
                            TextField(L10n.tr("contacts.form.company"), text: binding(\.company))
                                .appInputChrome()
                            TextField(L10n.tr("contacts.form.workPosition"), text: binding(\.workPosition))
                                .appInputChrome()
                        }

                        FormDisclosureSection(title: L10n.tr("contacts.form.section.channels"), isExpanded: $contactChannelsExpanded) {
                            TextField(L10n.tr("contacts.form.phones"), text: binding(\.phones))
                                .keyboardType(.phonePad)
                                .appInputChrome()
                            TextField(L10n.tr("contacts.form.emails"), text: binding(\.emails))
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .appInputChrome()
                            TextField(L10n.tr("contacts.form.facebook"), text: binding(\.facebook))
                                .textInputAutocapitalization(.never)
                                .appInputChrome()
                            TextField(L10n.tr("contacts.form.linkedin"), text: binding(\.linkedin))
                                .textInputAutocapitalization(.never)
                                .appInputChrome()
                            TextField(L10n.tr("contacts.form.instagram"), text: binding(\.instagram))
                                .textInputAutocapitalization(.never)
                                .appInputChrome()
                            TextField(L10n.tr("contacts.form.x"), text: binding(\.x))
                                .textInputAutocapitalization(.never)
                                .appInputChrome()
                        }

                        FormDisclosureSection(title: L10n.tr("contacts.form.section.personal"), isExpanded: $personalExpanded) {
                            TextField(L10n.tr("contacts.form.nickname"), text: binding(\.nickname))
                                .appInputChrome()
                            groupEditor
                            TextField(L10n.tr("contacts.form.notes"), text: binding(\.notes), axis: .vertical)
                                .lineLimit(3...5)
                                .appInputChrome()
                        }

                        interactionHistorySection

                        remindersSection

                        relationshipSection

                        Button(viewModel.selectedContactId == nil ? L10n.tr("contacts.form.save") : L10n.tr("contacts.form.update")) {
                            Task { await viewModel.save() }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!viewModel.canSubmitForm)

                        if hasInteractedWithForm, let validationMessage = viewModel.formValidationMessage {
                            Text(validationMessage)
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            hasInteractedWithForm = false
            applyBirthdayFromForm(viewModel.form.birthday)
        }
        .onChange(of: viewModel.form.birthday) { _, newValue in
            applyBirthdayFromForm(newValue)
        }
        .onChange(of: birthdayMonth) { _, _ in
            if let day = birthdayDay, day > maxDayInSelectedMonth {
                birthdayDay = maxDayInSelectedMonth
            }
            if birthdayMonth == nil {
                birthdayDay = nil
            }
            syncBirthdayToForm()
        }
        .onChange(of: birthdayYear) { _, _ in
            if let day = birthdayDay, day > maxDayInSelectedMonth {
                birthdayDay = maxDayInSelectedMonth
            }
            syncBirthdayToForm()
        }
        .onChange(of: birthdayDay) { _, _ in
            if birthdayDay != nil && birthdayMonth == nil {
                birthdayMonth = 1
            }
            syncBirthdayToForm()
        }
        .onChange(of: selectedPhotoItem) { _, item in
            Task {
                guard let item else { return }
                if let data = try? await item.loadTransferable(type: Data.self) {
                    viewModel.form.photoData = data
                }
            }
        }
        .sheet(isPresented: $isCoffeeDatePickerPresented) {
            NavigationStack {
                VStack(spacing: 12) {
                    DatePicker(
                        L10n.tr("contacts.form.reminder.coffeeDate"),
                        selection: coffeeReminderDateBinding,
                        in: Date()...,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)

                    DatePicker(
                        "",
                        selection: coffeeReminderDateBinding,
                        in: Date()...,
                        displayedComponents: [.hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.wheel)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .navigationTitle(L10n.tr("contacts.form.reminder.coffeeDate"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L10n.tr("common.ok")) {
                            isCoffeeDatePickerPresented = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var photoRow: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Group {
                    if let data = viewModel.form.photoData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Text(L10n.tr("contacts.form.addPhoto"))
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                            .foregroundStyle(AppTheme.muted)
                    }
                }
                .frame(width: 84, height: 84)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppTheme.stroke, lineWidth: 1)
                )
            }

            if viewModel.form.photoData != nil {
                Button(L10n.tr("common.remove")) {
                    viewModel.form.photoData = nil
                    selectedPhotoItem = nil
                }
                .foregroundStyle(AppTheme.muted)
            }
            Spacer()
        }
    }

    private var groupEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(L10n.tr("contacts.form.tags"), text: binding(\.tags))
                .appInputChrome()

            Text(L10n.tr("contacts.form.groups.quickAdd"))
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.muted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.availableGroups, id: \.self) { group in
                        FilterChip(
                            label: group,
                            isSelected: selectedDraftGroups.contains(where: { normalizeGroup($0) == normalizeGroup(group) }),
                            action: { toggleDraftGroup(group) }
                        )
                    }
                }
            }

            HStack(spacing: 8) {
                TextField(L10n.tr("contacts.form.groups.createPlaceholder"), text: $groupDraft)
                    .appInputChrome()

                Button {
                    addGroupFromDraft()
                } label: {
                    Text(L10n.tr("contacts.form.groups.create"))
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(AppTheme.tint)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(groupDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var relationshipSection: some View {
        FormDisclosureSection(title: L10n.tr("contacts.card.relationships"), isExpanded: $relationshipsExpanded) {
            Picker(L10n.tr("contacts.form.relationship.contact"), selection: binding(\.relationshipDraftTargetId)) {
                Text(L10n.tr("contacts.form.relationship.selectContact")).tag(Optional<UUID>.none)
                ForEach(viewModel.availableRelationshipTargets) { contact in
                    Text(contact.displayName).tag(Optional(contact.id))
                }
            }
            .pickerStyle(.menu)
            .appInputChrome()

            Picker(L10n.tr("contacts.form.relationship.type"), selection: binding(\.relationshipDraftType)) {
                ForEach(RelationshipType.allCases) { type in
                    Text(type.localizedTitle).tag(type)
                }
            }
            .pickerStyle(.menu)
            .appInputChrome()

            Button(viewModel.form.relationshipDraftIndex == nil ? L10n.tr("contacts.form.relationship.add") : L10n.tr("contacts.form.relationship.update")) {
                viewModel.addOrUpdateRelationshipDraft()
            }
            .buttonStyle(PrimaryButtonStyle())

            if !viewModel.form.relationships.isEmpty {
                ForEach(sortedDraftRelationships) { rel in
                    HStack {
                        HStack(spacing: 10) {
                            Image(systemName: rel.type.symbolName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.tint)
                                .frame(width: 26, height: 26)
                                .background(AppTheme.tint.opacity(0.12))
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.relationshipTargetName(rel.contactId))
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                    .foregroundStyle(AppTheme.text)
                                    .lineLimit(1)
                                Text(rel.type.localizedTitle)
                                    .font(.system(.caption, design: .rounded).weight(.medium))
                                    .foregroundStyle(AppTheme.muted)
                            }
                        }
                        Spacer()
                        Button {
                            viewModel.editRelationship(rel)
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(AppTheme.muted)
                        Button(role: .destructive) {
                            viewModel.removeRelationship(rel)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppTheme.surfaceAlt.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppTheme.stroke.opacity(0.45), lineWidth: 1)
                    )
                }
            }
        }
    }

    private var remindersSection: some View {
        FormDisclosureSection(title: L10n.tr("contacts.form.section.reminders"), isExpanded: $remindersExpanded) {
            Toggle(L10n.tr("contacts.form.reminder.coffee"), isOn: coffeeReminderEnabledBinding)
                .toggleStyle(.switch)

            if coffeeReminderEnabledBinding.wrappedValue {
                Button {
                    isCoffeeDatePickerPresented = true
                } label: {
                    HStack(spacing: 10) {
                        Text(coffeeReminderDateText)
                            .font(.system(.body, design: .rounded).weight(.medium))
                            .foregroundStyle(AppTheme.text)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.surfaceAlt)
                            .clipShape(Capsule())

                        Text(coffeeReminderTimeText)
                            .font(.system(.body, design: .rounded).weight(.medium))
                            .foregroundStyle(AppTheme.text)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.surfaceAlt)
                            .clipShape(Capsule())

                        Spacer(minLength: 0)

                        Image(systemName: "calendar")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.muted)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .appInputChrome()
            }

            Divider()

            Toggle(L10n.tr("contacts.form.reminder.stayInTouch"), isOn: stayInTouchEnabledBinding)
                .toggleStyle(.switch)

            if stayInTouchEnabledBinding.wrappedValue {
                Stepper(value: stayInTouchDaysBinding, in: 1 ... 365) {
                    Text(L10n.format("contacts.form.reminder.stayInTouchDays", stayInTouchDaysBinding.wrappedValue))
                }
            }
        }
    }

    private var interactionHistorySection: some View {
        FormDisclosureSection(title: L10n.tr("contacts.form.section.interactions"), isExpanded: $interactionsExpanded) {
            DatePicker(
                L10n.tr("contacts.form.interaction.date"),
                selection: Binding(
                    get: { viewModel.form.interactionDraftDate },
                    set: { newValue in
                        hasInteractedWithForm = true
                        viewModel.form.interactionDraftDate = newValue
                    }
                ),
                displayedComponents: [.date, .hourAndMinute]
            )

            TextField(L10n.tr("contacts.form.interaction.note"), text: binding(\.interactionDraftNote), axis: .vertical)
                .lineLimit(3...3)
                .appInputChrome()

            Button(viewModel.form.editingInteractionId == nil ? L10n.tr("contacts.form.interaction.add") : L10n.tr("contacts.form.interaction.update")) {
                viewModel.addOrUpdateInteractionDraft()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!viewModel.canSubmitInteractionDraft)

            if sortedDraftInteractions.isEmpty {
                Text(L10n.tr("contacts.form.interaction.empty"))
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(AppTheme.muted)
            } else {
                ForEach(sortedDraftInteractions) { interaction in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.tint)
                            .frame(width: 26, height: 26)
                            .background(AppTheme.tint.opacity(0.12))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(interactionListDateFormatter.string(from: Date(timeIntervalSince1970: interaction.date)))
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.text)
                            Text(interaction.note)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(AppTheme.muted)
                                .lineLimit(3)
                        }

                        Spacer(minLength: 0)

                        Button {
                            hasInteractedWithForm = true
                            viewModel.editInteraction(interaction)
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(AppTheme.muted)

                        Button(role: .destructive) {
                            hasInteractedWithForm = true
                            viewModel.removeInteraction(interaction)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppTheme.surfaceAlt.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppTheme.stroke.opacity(0.45), lineWidth: 1)
                    )
                }
            }
        }
    }

    private var sortedDraftRelationships: [ContactRelationship] {
        viewModel.form.relationships.sorted { lhs, rhs in
            if lhs.type.sortRank == rhs.type.sortRank {
                return viewModel.relationshipTargetName(lhs.contactId) < viewModel.relationshipTargetName(rhs.contactId)
            }
            return lhs.type.sortRank < rhs.type.sortRank
        }
    }

    private var selectedDraftGroups: [String] {
        parseGroups(viewModel.form.tags)
    }

    private func addGroupFromDraft() {
        let trimmed = groupDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        toggleDraftGroup(trimmed, forceInsert: true)
        groupDraft = ""
    }

    private func toggleDraftGroup(_ group: String, forceInsert: Bool = false) {
        let trimmed = group.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let targetKey = normalizeGroup(trimmed)
        var groups = selectedDraftGroups

        if let existingIndex = groups.firstIndex(where: { normalizeGroup($0) == targetKey }) {
            if forceInsert {
                groups[existingIndex] = trimmed
            } else {
                groups.remove(at: existingIndex)
            }
        } else {
            groups.append(trimmed)
        }

        hasInteractedWithForm = true
        viewModel.form.tags = groups.joined(separator: ", ")
    }

    private func parseGroups(_ value: String) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []

        for part in value.split(separator: ",") {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = normalizeGroup(trimmed)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(trimmed)
        }

        return result
    }

    private func normalizeGroup(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private var sortedDraftInteractions: [ContactInteraction] {
        viewModel.form.interactions.sorted { $0.date > $1.date }
    }

    private var interactionListDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("d MMM yyyy, HH:mm")
        return formatter
    }

    private func applyBirthdayFromForm(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            birthdayYear = nil
            birthdayMonth = nil
            birthdayDay = nil
            return
        }

        let parsed = BirthdayValue(rawValue: raw) ?? BirthdayValue(rawValue: "1990-01")
        guard let parsed else { return }

        birthdayYear = parsed.year
        birthdayMonth = parsed.month
        birthdayDay = parsed.day
    }

    private func syncBirthdayToForm() {
        guard let year = birthdayYear else {
            viewModel.form.birthday = ""
            return
        }

        let value: BirthdayValue?
        if let month = birthdayMonth, let day = birthdayDay {
            value = BirthdayValue(year: year, month: month, day: day)
        } else if let month = birthdayMonth {
            value = BirthdayValue(year: year, month: month, day: nil)
        } else {
            value = BirthdayValue(year: year, month: nil, day: nil)
        }

        guard let value else {
            viewModel.form.birthday = ""
            return
        }

        if viewModel.form.birthday != value.rawValue {
            viewModel.form.birthday = value.rawValue
        }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<ContactFormState, T>) -> Binding<T> {
        Binding(
            get: { viewModel.form[keyPath: keyPath] },
            set: {
                hasInteractedWithForm = true
                viewModel.form[keyPath: keyPath] = $0
            }
        )
    }

    private var coffeeReminderEnabledBinding: Binding<Bool> {
        Binding(
            get: { viewModel.form.coffeeReminderAt != nil },
            set: { isEnabled in
                if isEnabled {
                    if viewModel.form.coffeeReminderAt == nil {
                        viewModel.form.coffeeReminderAt = Date().addingTimeInterval(3600).timeIntervalSince1970
                    }
                } else {
                    viewModel.form.coffeeReminderAt = nil
                }
            }
        )
    }

    private var coffeeReminderDateBinding: Binding<Date> {
        Binding(
            get: {
                if let timestamp = viewModel.form.coffeeReminderAt {
                    return Date(timeIntervalSince1970: timestamp)
                }
                return Date().addingTimeInterval(3600)
            },
            set: { newValue in
                viewModel.form.coffeeReminderAt = newValue.timeIntervalSince1970
            }
        )
    }

    private var stayInTouchEnabledBinding: Binding<Bool> {
        Binding(
            get: { (viewModel.form.stayInTouchEveryDays ?? 0) > 0 },
            set: { isEnabled in
                if isEnabled {
                    if (viewModel.form.stayInTouchEveryDays ?? 0) <= 0 {
                        viewModel.form.stayInTouchEveryDays = 30
                    }
                } else {
                    viewModel.form.stayInTouchEveryDays = nil
                }
            }
        )
    }

    private var stayInTouchDaysBinding: Binding<Int> {
        Binding(
            get: {
                let value = viewModel.form.stayInTouchEveryDays ?? 30
                return min(max(value, 1), 365)
            },
            set: { newValue in
                viewModel.form.stayInTouchEveryDays = min(max(newValue, 1), 365)
            }
        )
    }

    private var coffeeReminderDateText: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = locale
        formatter.dateFormat = "MMM/dd/yy"
        return formatter.string(from: coffeeReminderDateBinding.wrappedValue)
    }

    private var coffeeReminderTimeText: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = locale
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: coffeeReminderDateBinding.wrappedValue)
    }

    private static var monthLabels: [String] {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale.autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return (1...12).compactMap { month in
            let components = DateComponents(year: 2001, month: month, day: 1)
            guard let date = formatter.calendar.date(from: components) else { return nil }
            return formatter.string(from: date)
        }
    }

    private static var yearOptions: [Int] {
        let currentYear = Calendar(identifier: .gregorian).component(.year, from: Date())
        return Array((1900...currentYear).reversed())
    }

    private var maxDayInSelectedMonth: Int {
        guard let birthdayYear, let birthdayMonth else {
            return 31
        }

        let calendar = Calendar(identifier: .gregorian)
        let components = DateComponents(year: birthdayYear, month: birthdayMonth)
        guard let date = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return 31
        }
        return range.count
    }

    private var validDaysInSelectedMonth: [Int] {
        Array(1...maxDayInSelectedMonth)
    }
}

private struct FormDisclosureSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder var content: Content

    var body: some View {
        SectionCard {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Text(title)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.muted)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

private struct CityAutocompleteField: View {
    let title: String
    @Binding var text: String

    @State private var suggestions: [CitySuggestion] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(title, text: $text)
                .appInputChrome()
                .onChange(of: text) { _, newValue in
                    searchTask?.cancel()
                    searchTask = Task {
                        try? await Task.sleep(for: .milliseconds(350))
                        if Task.isCancelled { return }
                        suggestions = await CitySearchService.search(query: newValue)
                    }
                }

            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions) { suggestion in
                        Button {
                            text = suggestion.label
                            suggestions = []
                        } label: {
                            HStack {
                                Text(suggestion.label)
                                    .font(.system(.footnote, design: .rounded))
                                    .foregroundStyle(AppTheme.text)
                                Spacer()
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppTheme.stroke, lineWidth: 1)
                )
            }
        }
    }
}

private struct AddressSuggestion: Identifiable {
    let title: String
    let subtitle: String

    var id: String { "\(title)|\(subtitle)" }

    var label: String {
        subtitle.isEmpty ? title : "\(title), \(subtitle)"
    }
}

@MainActor
private final class AddressAutocompleteModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var suggestions: [AddressSuggestion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            suggestions = []
            completer.queryFragment = ""
            return
        }
        completer.queryFragment = trimmed
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let mapped = completer.results.map { result in
            AddressSuggestion(title: result.title, subtitle: result.subtitle)
        }
        suggestions = Array(mapped.prefix(6))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
    }
}

private struct AddressAutocompleteField: View {
    let title: String
    @Binding var text: String

    @StateObject private var model = AddressAutocompleteModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(title, text: $text)
                .appInputChrome()
                .onChange(of: text) { _, newValue in
                    model.update(query: newValue)
                }

            if !model.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(model.suggestions) { suggestion in
                        Button {
                            text = suggestion.label
                            model.suggestions = []
                        } label: {
                            HStack {
                                Text(suggestion.label)
                                    .font(.system(.footnote, design: .rounded))
                                    .foregroundStyle(AppTheme.text)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppTheme.stroke, lineWidth: 1)
                )
            }
        }
    }
}

private struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: spacing)], alignment: .leading, spacing: spacing) {
            content
        }
    }
}
