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
                        Text("Contacts")
                            .font(.system(size: 32, weight: .bold, design: .serif))
                            .foregroundStyle(AppTheme.text)
                        SectionCard {
                            Text("Setting up")
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.text)
                            Text("Initializing local encryption and storage.")
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
                                    Text("No contacts yet")
                                        .font(.system(.headline, design: .rounded).weight(.semibold))
                                        .foregroundStyle(AppTheme.text)
                                    Text("Add someone above or import from your phone contacts once imports are enabled.")
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(AppTheme.muted)
                                }
                            } else {
                                ForEach(viewModel.filteredContacts) { contact in
                                    ContactCardView(
                                        contact: contact,
                                        relationshipLabel: { id in viewModel.relationshipTargetName(id) },
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
            .navigationTitle("Contacts")
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
        .alert("Delete contact", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let pendingDelete {
                    Task { await viewModel.delete(pendingDelete) }
                }
                self.pendingDelete = nil
            }
        } message: {
            Text("This contact will be removed from this device.")
        }
        .alert("Notice", isPresented: Binding(
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Build strong relationships with reminders and insights.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.muted)
                TextField("Search by name, tag, email", text: $viewModel.query)
                    .textInputAutocapitalization(.never)
                    .appInputChrome()
            }

            HStack {
                Text("Recent")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                Spacer()
                Text("\(viewModel.filteredContacts.count) saved")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(AppTheme.muted)
            }
        }
    }
}

private struct ContactCardView: View {
    let contact: Contact
    let relationshipLabel: (UUID) -> String
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
                Text("🎂 \(birthday)")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(AppTheme.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.accent.opacity(0.18))
                    .clipShape(Capsule())
            }

            if let city = contact.placeOfLiving, !city.isEmpty {
                Text("Lives in \(city)")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppTheme.muted)
            }

            if !contact.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(contact.tags.prefix(3), id: \.self) { tag in
                        PillView(label: tag)
                    }
                }
            }

            if !contact.relationships.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Relationship")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .textCase(.uppercase)
                        .foregroundStyle(AppTheme.muted)
                    ForEach(contact.relationships) { relationship in
                        Text("\(relationship.type.rawValue) · \(relationshipLabel(relationship.contactId))")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(AppTheme.text)
                    }
                }
            }

            if let notes = contact.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(2)
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
}

private struct ContactFormSheet: View {
    @ObservedObject var viewModel: ContactsViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var birthDate = Date.fromISO("1995-01-01") ?? Date()

    var body: some View {
        NavigationStack {
            ScreenBackground {
                ScrollView {
                    VStack(spacing: 12) {
                        SectionCard {
                            HStack {
                                Text(viewModel.selectedContactId == nil ? "Add a contact" : "Edit contact")
                                    .font(.system(.title3, design: .rounded).weight(.semibold))
                                    .foregroundStyle(AppTheme.text)
                                Spacer()
                                Button("Cancel") {
                                    viewModel.cancelForm()
                                }
                                .foregroundStyle(AppTheme.muted)
                            }

                            photoRow

                            Group {
                                TextField("First name", text: binding(\.firstName))
                                    .appInputChrome()
                                TextField("Last name", text: binding(\.lastName))
                                    .appInputChrome()
                                TextField("Nickname", text: binding(\.nickname))
                                    .appInputChrome()
                                DatePicker("Birthday", selection: $birthDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .appInputChrome()
                                    .onChange(of: birthDate) { _, newValue in
                                        viewModel.form.birthday = newValue.isoDateString
                                    }
                                CityAutocompleteField(title: "Place of birth", text: binding(\.placeOfBirth))
                                AddressAutocompleteField(title: "Place of living (full address)", text: binding(\.placeOfLiving))
                                TextField("Company", text: binding(\.company))
                                    .appInputChrome()
                                TextField("Work position", text: binding(\.workPosition))
                                    .appInputChrome()
                                TextField("Phones (comma separated)", text: binding(\.phones))
                                    .keyboardType(.phonePad)
                                    .appInputChrome()
                                TextField("Emails (comma separated)", text: binding(\.emails))
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                    .appInputChrome()
                                TextField("Tags (comma separated)", text: binding(\.tags))
                                    .appInputChrome()
                                TextField("Notes", text: binding(\.notes), axis: .vertical)
                                    .lineLimit(3...5)
                                    .appInputChrome()
                            }
                        }

                        relationshipSection

                        Button(viewModel.selectedContactId == nil ? "Save contact" : "Update contact") {
                            Task { await viewModel.save() }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(20)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            birthDate = Date.fromISO(viewModel.form.birthday) ?? Date.fromISO("1995-01-01") ?? Date()
        }
        .onChange(of: viewModel.form.birthday) { _, newValue in
            birthDate = Date.fromISO(newValue) ?? birthDate
        }
        .onChange(of: selectedPhotoItem) { _, item in
            Task {
                guard let item else { return }
                if let data = try? await item.loadTransferable(type: Data.self) {
                    viewModel.form.photoData = data
                }
            }
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
                        Text("Add photo")
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
                Button("Remove") {
                    viewModel.form.photoData = nil
                    selectedPhotoItem = nil
                }
                .foregroundStyle(AppTheme.muted)
            }
            Spacer()
        }
    }

    private var relationshipSection: some View {
        SectionCard {
            Text("Relationships")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(AppTheme.text)

            Picker("Contact", selection: binding(\.relationshipDraftTargetId)) {
                Text("Select contact").tag(Optional<UUID>.none)
                ForEach(viewModel.availableRelationshipTargets) { contact in
                    Text(contact.displayName).tag(Optional(contact.id))
                }
            }
            .pickerStyle(.menu)
            .appInputChrome()

            Picker("Type", selection: binding(\.relationshipDraftType)) {
                ForEach(RelationshipType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.menu)
            .appInputChrome()

            Button(viewModel.form.relationshipDraftIndex == nil ? "Add relationship" : "Update relationship") {
                viewModel.addOrUpdateRelationshipDraft()
            }
            .buttonStyle(PrimaryButtonStyle())

            if !viewModel.form.relationships.isEmpty {
                ForEach(viewModel.form.relationships) { rel in
                    HStack {
                        Text("\(rel.type.rawValue) · \(viewModel.relationshipTargetName(rel.contactId))")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(AppTheme.text)
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
                }
            }
        }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<ContactFormState, T>) -> Binding<T> {
        Binding(
            get: { viewModel.form[keyPath: keyPath] },
            set: { viewModel.form[keyPath: keyPath] = $0 }
        )
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

private extension Date {
    static func fromISO(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    var isoDateString: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }
}
