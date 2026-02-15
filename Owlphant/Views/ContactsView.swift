import Combine
import PhotosUI
import MapKit
import SwiftUI

private enum ContactsLayoutMode: String, CaseIterable, Identifiable {
    case list
    case card
    case relationship

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .list:
            return L10n.tr("contacts.view.mode.list")
        case .card:
            return L10n.tr("contacts.view.mode.card")
        case .relationship:
            return L10n.tr("contacts.view.mode.relationship")
        }
    }
}

struct ContactsView: View {
    @ObservedObject var viewModel: ContactsViewModel
    @State private var pendingBulkDelete = false
    @State private var selectedContactIDs: Set<UUID> = []
    @State private var selectionHapticTick = 0
    @FocusState private var isSearchFocused: Bool
    @State private var layoutMode: ContactsLayoutMode = .list

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
                                Group {
                                    switch layoutMode {
                                    case .list:
                                        ForEach(viewModel.filteredContacts) { contact in
                                            ContactListRowView(
                                                contact: contact,
                                                isSelectionMode: isSelectionMode,
                                                isSelected: isContactSelected(contact.id),
                                                onPrimaryTap: {
                                                    if isSelectionMode {
                                                        toggleSelection(contact.id)
                                                    } else {
                                                        viewModel.startEdit(contact)
                                                    }
                                                },
                                                onLongPress: { beginSelection(with: contact.id) }
                                            )
                                            .id("list-\(contact.id.uuidString)")
                                        }
                                    case .card:
                                        ForEach(viewModel.filteredContacts) { contact in
                                            ContactCardView(
                                                contact: contact,
                                                relationshipLabel: { id in viewModel.relationshipTargetName(id) },
                                                onRelationshipTap: { relationship in
                                                    guard !isSelectionMode else { return }
                                                    viewModel.startEdit(contact)
                                                    viewModel.editRelationship(relationship)
                                                },
                                                isSelectionMode: isSelectionMode,
                                                isSelected: isContactSelected(contact.id),
                                                onTap: {
                                                    if isSelectionMode {
                                                        toggleSelection(contact.id)
                                                    } else {
                                                        viewModel.startEdit(contact)
                                                    }
                                                },
                                                onLongPress: { beginSelection(with: contact.id) },
                                                onToggleSelection: { toggleSelection(contact.id) }
                                            )
                                            .id("card-\(contact.id.uuidString)")
                                        }
                                    case .relationship:
                                        SectionCard {
                                            Text(L10n.tr("contacts.relationship.title"))
                                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                                .foregroundStyle(AppTheme.text)
                                            Text(L10n.tr("contacts.relationship.subtitle"))
                                                .font(.system(.subheadline, design: .rounded))
                                                .foregroundStyle(AppTheme.muted)

                                            RelationshipGraphView(
                                                contacts: viewModel.filteredContacts,
                                                onContactTap: { contact in
                                                    viewModel.startEdit(contact)
                                                }
                                            )
                                            .frame(height: 380)
                                        }
                                    }
                                }
                                .id(layoutMode)
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
                if isSelectionMode {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(L10n.tr("common.cancel")) {
                            clearSelection()
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            pendingBulkDelete = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(selectedContactIDs.isEmpty)
                        .accessibilityLabel(L10n.tr("common.delete"))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !isSelectionMode {
                        Button {
                            viewModel.startCreate()
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(AppTheme.tint)
                        }
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
        .alert(L10n.tr("contacts.alert.delete.multiple.title"), isPresented: $pendingBulkDelete) {
            Button(L10n.tr("common.cancel"), role: .cancel) {
                pendingBulkDelete = false
            }
            Button(L10n.tr("common.delete"), role: .destructive) {
                let ids = selectedContactIDs
                Task {
                    await viewModel.deleteContacts(ids: ids)
                    clearSelection()
                }
                pendingBulkDelete = false
            }
        } message: {
            Text(L10n.format("contacts.alert.delete.multiple.message", selectedContactIDs.count))
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
        .onChange(of: layoutMode) { _, newValue in
            if newValue == .relationship {
                clearSelection()
            }
        }
        .onChange(of: viewModel.contacts) { _, newValue in
            let validIDs = Set(newValue.map(\.id))
            selectedContactIDs = selectedContactIDs.intersection(validIDs)
        }
        .sensoryFeedback(.selection, trigger: selectionHapticTick)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            searchPill

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(L10n.tr("contacts.filters.quick"))
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(AppTheme.muted)
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

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(L10n.tr("contacts.view.title"))
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(AppTheme.muted)
                }

                HStack(spacing: 8) {
                    ForEach(ContactsLayoutMode.allCases) { mode in
                        FilterChip(
                            label: mode.localizedTitle,
                            isSelected: layoutMode == mode,
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    layoutMode = mode
                                }
                            }
                        )
                    }
                }
            }

            if layoutMode != .relationship {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(L10n.tr("contacts.sort.field.title"))
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(AppTheme.muted)

                        Spacer()

                        Text(savedContactsText)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(AppTheme.muted)
                    }

                    HStack(spacing: 8) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(ContactSortField.allCases, id: \.self) { field in
                                    FilterChip(
                                        label: field.localizedTitle,
                                        isSelected: viewModel.sortField == field,
                                        action: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                viewModel.sortField = field
                                            }
                                        }
                                    )
                                }
                            }
                        }

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                toggleSortDirection()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: sortDirectionIcon)
                                    .font(.system(size: 11, weight: .bold))
                                Text(sortDirectionShortTitle)
                                    .font(.system(.caption, design: .rounded).weight(.semibold))
                            }
                            .foregroundStyle(sortDirectionForeground)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(sortDirectionBackground)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(sortDirectionBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.tr("contacts.sort.direction.title"))
                        .accessibilityValue(viewModel.sortDirection.localizedTitle)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.sortField)
                .animation(.easeInOut(duration: 0.2), value: viewModel.sortDirection)
            }
        }
    }

    private var searchPill: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(searchIconColor)

            TextField(L10n.tr("contacts.header.searchPlaceholder"), text: $viewModel.query)
                .textInputAutocapitalization(.never)
                .focused($isSearchFocused)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(AppTheme.text)

            if !viewModel.query.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.query = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(searchIconColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.tr("common.clear"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(searchBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(searchBorder, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
        .animation(.easeInOut(duration: 0.2), value: viewModel.query)
        .accessibilityLabel(L10n.tr("contacts.header.searchPlaceholder"))
    }

    private var savedContactsText: String {
        L10n.format("contacts.header.savedCount", viewModel.filteredContacts.count)
    }

    private var sortDirectionIcon: String {
        switch viewModel.sortDirection {
        case .ascending:
            return "arrow.up"
        case .descending:
            return "arrow.down"
        }
    }

    private var sortDirectionShortTitle: String {
        switch viewModel.sortDirection {
        case .ascending:
            return L10n.tr("contacts.sort.direction.short.ascending")
        case .descending:
            return L10n.tr("contacts.sort.direction.short.descending")
        }
    }

    private var sortDirectionForeground: Color {
        switch viewModel.sortDirection {
        case .ascending:
            return AppTheme.tint
        case .descending:
            return AppTheme.accent
        }
    }

    private var sortDirectionBackground: Color {
        switch viewModel.sortDirection {
        case .ascending:
            return AppTheme.tint.opacity(0.18)
        case .descending:
            return AppTheme.accent.opacity(0.2)
        }
    }

    private var sortDirectionBorder: Color {
        switch viewModel.sortDirection {
        case .ascending:
            return AppTheme.tint.opacity(0.55)
        case .descending:
            return AppTheme.accent.opacity(0.55)
        }
    }

    private var searchBackground: Color {
        isSearchFocused ? AppTheme.tint.opacity(0.14) : AppTheme.surfaceAlt
    }

    private var searchBorder: Color {
        isSearchFocused ? AppTheme.tint.opacity(0.7) : AppTheme.stroke
    }

    private var searchIconColor: Color {
        isSearchFocused ? AppTheme.tint : AppTheme.muted
    }

    private func toggleSortDirection() {
        switch viewModel.sortDirection {
        case .ascending:
            viewModel.sortDirection = .descending
        case .descending:
            viewModel.sortDirection = .ascending
        }
    }

    private var isSelectionMode: Bool {
        !selectedContactIDs.isEmpty
    }

    private func isContactSelected(_ id: UUID) -> Bool {
        selectedContactIDs.contains(id)
    }

    private func beginSelection(with id: UUID) {
        guard layoutMode != .relationship else { return }
        let wasSelectionMode = isSelectionMode
        selectedContactIDs.insert(id)
        if !wasSelectionMode {
            triggerSelectionHaptic()
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedContactIDs.contains(id) {
            selectedContactIDs.remove(id)
        } else {
            selectedContactIDs.insert(id)
        }
    }

    private func clearSelection() {
        selectedContactIDs.removeAll()
        pendingBulkDelete = false
    }

    private func triggerSelectionHaptic() {
        selectionHapticTick += 1
    }
}

private struct ContactCardView: View {
    let contact: Contact
    let relationshipLabel: (UUID) -> String
    let onRelationshipTap: (ContactRelationship) -> Void
    let isSelectionMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onToggleSelection: () -> Void

    var body: some View {
        SectionCard {
            HStack(alignment: .center, spacing: 10) {
                if isSelectionMode {
                    Button(action: onToggleSelection) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(isSelected ? AppTheme.tint : AppTheme.muted)
                    }
                    .buttonStyle(.plain)
                } else {
                    ContactAvatarView(contact: contact, size: 46)
                }
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

            if !visibleCustomFields.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(visibleCustomFields) { customField in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(customField.label):")
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.text)
                            Text(customField.value)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(AppTheme.muted)
                                .lineLimit(1)
                        }
                    }

                    if hiddenCustomFieldCount > 0 {
                        Text("+\(hiddenCustomFieldCount)")
                            .font(.system(.caption2, design: .rounded).weight(.semibold))
                            .foregroundStyle(AppTheme.muted)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.surfaceAlt.opacity(0.5))
                            .clipShape(Capsule())
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
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                onTap()
            }
        )
        .onLongPressGesture(perform: onLongPress)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? AppTheme.tint : Color.clear, lineWidth: 2)
        )
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

    private var visibleCustomFields: [ContactCustomField] {
        Array(contact.resolvedCustomFields.prefix(2))
    }

    private var hiddenCustomFieldCount: Int {
        max(0, contact.resolvedCustomFields.count - visibleCustomFields.count)
    }

    private static let interactionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("d MMM, HH:mm")
        return formatter
    }()
}

private struct ContactListRowView: View {
    let contact: Contact
    let isSelectionMode: Bool
    let isSelected: Bool
    let onPrimaryTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            avatarOrSelectionIndicator

            HStack(spacing: 6) {
                Text(listDisplayName)
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(minWidth: 100, alignment: .leading)
                    .layoutPriority(2)

                metadataSeparator
                    .padding(.horizontal, 1)

                HStack(spacing: 3) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.muted)

                    Text(placeOfLivingDisplay)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(minWidth: 56, maxWidth: .infinity, alignment: .leading)
                .layoutPriority(0)

                metadataSeparator
                    .padding(.horizontal, 1)

                Text(groupsDisplay)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(minWidth: 78, maxWidth: 128, alignment: .trailing)
                    .layoutPriority(1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onPrimaryTap)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? AppTheme.tint.opacity(0.16) : AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? AppTheme.tint.opacity(0.7) : AppTheme.stroke, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onLongPressGesture(perform: onLongPress)
    }

    @ViewBuilder
    private var avatarOrSelectionIndicator: some View {
        if isSelectionMode {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isSelected ? AppTheme.tint : AppTheme.muted)
                .frame(width: 32, height: 32)
        } else {
            ContactAvatarView(contact: contact, size: 32)
        }
    }

    private var metadataSeparator: some View {
        Text("•")
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(AppTheme.muted.opacity(0.42))
    }

    private var listDisplayName: String {
        let first = contact.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = contact.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let combined = "\(first) \(last)".trimmingCharacters(in: .whitespacesAndNewlines)
        return combined.isEmpty ? L10n.tr("contacts.unnamed") : combined
    }

    private var placeOfLivingDisplay: String {
        let place = (contact.placeOfLiving ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !place.isEmpty else { return "-" }

        let city = place
            .split(separator: ",", maxSplits: 1, omittingEmptySubsequences: true)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return city.isEmpty ? place : city
    }

    private var groupsDisplay: String {
        let cleanedGroups = contact.groups
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !cleanedGroups.isEmpty else { return "-" }

        if cleanedGroups.count == 1 {
            return cleanedGroups[0]
        }

        if cleanedGroups.count == 2 {
            let combined = "\(cleanedGroups[0]), \(cleanedGroups[1])"
            return combined.count <= 22 ? combined : "\(cleanedGroups[0]) +1"
        }

        let preview = cleanedGroups.prefix(2).joined(separator: ", ")
        let remaining = cleanedGroups.count - 2
        if remaining > 0 {
            return "\(preview) +\(remaining)"
        }
        return preview
    }
}

private struct RelationshipGraphView: View {
    let contacts: [Contact]
    let onContactTap: (Contact) -> Void

    var body: some View {
        GeometryReader { proxy in
            let nodes = sortedContacts
            let edges = graphEdges
            let positions = Self.circularLayout(for: nodes, in: proxy.size)

            if edges.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(AppTheme.muted)
                    Text(L10n.tr("contacts.relationship.empty"))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(AppTheme.muted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ZStack {
                    ForEach(edges) { edge in
                        if let start = positions[edge.sourceId],
                           let end = positions[edge.targetId] {
                            Path { path in
                                path.move(to: start)
                                path.addLine(to: end)
                            }
                            .stroke(AppTheme.stroke.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        }
                    }

                    ForEach(nodes) { contact in
                        if let point = positions[contact.id] {
                            VStack(spacing: 5) {
                                Button {
                                    onContactTap(contact)
                                } label: {
                                    ContactAvatarView(contact: contact, size: 44)
                                }
                                .buttonStyle(.plain)

                                Text(contact.displayName)
                                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                                    .foregroundStyle(AppTheme.text)
                                    .lineLimit(1)
                                    .frame(maxWidth: 84)
                            }
                            .position(point)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var sortedContacts: [Contact] {
        contacts.sorted { lhs, rhs in
            let lhsName = lhs.displayName.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let rhsName = rhs.displayName.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            if lhsName != rhsName {
                return lhsName < rhsName
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private var graphEdges: [GraphEdge] {
        let visibleIds = Set(contacts.map(\.id))
        var seen: Set<String> = []
        var result: [GraphEdge] = []

        for contact in contacts {
            for relationship in contact.relationships {
                guard visibleIds.contains(relationship.contactId), relationship.contactId != contact.id else { continue }

                let low = min(contact.id.uuidString, relationship.contactId.uuidString)
                let high = max(contact.id.uuidString, relationship.contactId.uuidString)
                let key = "\(low)|\(high)"

                guard !seen.contains(key) else { continue }
                seen.insert(key)
                result.append(GraphEdge(sourceId: contact.id, targetId: relationship.contactId))
            }
        }

        return result
    }

    private static func circularLayout(for contacts: [Contact], in size: CGSize) -> [UUID: CGPoint] {
        guard !contacts.isEmpty else { return [:] }

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = max(30, min(size.width, size.height) * 0.36)
        let startAngle = -Double.pi / 2

        if contacts.count == 1 {
            return [contacts[0].id: center]
        }

        var positions: [UUID: CGPoint] = [:]
        for (index, contact) in contacts.enumerated() {
            let progress = Double(index) / Double(contacts.count)
            let angle = startAngle + progress * Double.pi * 2
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            positions[contact.id] = point
        }
        return positions
    }
}

private struct GraphEdge: Identifiable {
    let sourceId: UUID
    let targetId: UUID

    var id: String {
        "\(sourceId.uuidString)|\(targetId.uuidString)"
    }
}

private struct ContactAvatarView: View {
    let contact: Contact
    let size: CGFloat

    var body: some View {
        if let base64 = contact.photoDataBase64,
           let data = Data(base64Encoded: base64),
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(AppTheme.tint.opacity(0.14))
                .frame(width: size, height: size)
                .overlay {
                    Text(contact.initials)
                        .font(.system(size: max(11, size * 0.33), weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.text)
                }
        }
    }
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
    @State private var pendingDeleteContact = false

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
                            customFieldsEditor
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

                        if viewModel.selectedContactId != nil {
                            Button(L10n.tr("common.delete"), role: .destructive) {
                                pendingDeleteContact = true
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }

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
        .alert(L10n.tr("contacts.alert.delete.title"), isPresented: $pendingDeleteContact) {
            Button(L10n.tr("common.cancel"), role: .cancel) {
                pendingDeleteContact = false
            }
            Button(L10n.tr("common.delete"), role: .destructive) {
                guard let contact = selectedContactForDelete else {
                    pendingDeleteContact = false
                    return
                }
                Task {
                    await viewModel.delete(contact)
                    viewModel.cancelForm()
                }
                pendingDeleteContact = false
            }
        } message: {
            Text(L10n.tr("contacts.alert.delete.message"))
        }
    }

    private var selectedContactForDelete: Contact? {
        guard let selectedContactId = viewModel.selectedContactId else { return nil }
        return viewModel.contacts.first { $0.id == selectedContactId }
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

    private var customFieldsEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("contacts.form.customFields.title"))
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.muted)

            TextField(
                L10n.tr("contacts.form.customFields.labelPlaceholder"),
                text: Binding(
                    get: { viewModel.form.customFieldDraftLabel },
                    set: { newValue in
                        hasInteractedWithForm = true
                        viewModel.form.customFieldDraftLabel = newValue
                    }
                )
            )
            .appInputChrome()

            TextField(
                L10n.tr("contacts.form.customFields.valuePlaceholder"),
                text: Binding(
                    get: { viewModel.form.customFieldDraftValue },
                    set: { newValue in
                        hasInteractedWithForm = true
                        viewModel.form.customFieldDraftValue = newValue
                    }
                )
            )
            .appInputChrome()

            HStack(spacing: 8) {
                Button(viewModel.form.editingCustomFieldId == nil ? L10n.tr("contacts.form.customFields.add") : L10n.tr("contacts.form.customFields.update")) {
                    hasInteractedWithForm = true
                    viewModel.addOrUpdateCustomFieldDraft()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canSubmitCustomFieldDraft)

                if viewModel.form.editingCustomFieldId != nil {
                    Button(L10n.tr("common.cancel")) {
                        hasInteractedWithForm = true
                        viewModel.resetCustomFieldDraft()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.muted)
                }
            }

            if viewModel.form.customFields.isEmpty {
                Text(L10n.tr("contacts.form.customFields.empty"))
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(AppTheme.muted)
            } else {
                ForEach(viewModel.form.customFields) { customField in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(customField.label)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.text)
                            Text(customField.value)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(AppTheme.muted)
                                .lineLimit(2)
                        }

                        Spacer(minLength: 0)

                        Button {
                            hasInteractedWithForm = true
                            viewModel.editCustomField(customField)
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(AppTheme.muted)

                        Button(role: .destructive) {
                            hasInteractedWithForm = true
                            viewModel.removeCustomField(customField)
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

    private var canSubmitCustomFieldDraft: Bool {
        !viewModel.form.customFieldDraftLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !viewModel.form.customFieldDraftValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
