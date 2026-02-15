#if canImport(MessageUI)
import MessageUI
#endif
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct HelpView: View {
    @Environment(\.openURL) private var openURL

    @State private var subject = ""
    @State private var suggestion = ""
    @State private var contactEmail = ""
    @State private var isPresentingMailComposer = false
    @State private var alertMessage: String?

    private let supportEmail = "ivanjuric.work@gmail.com"

    var body: some View {
        NavigationStack {
            ScreenBackground {
                ScrollView {
                    VStack(spacing: 18) {
                        SectionCard {
                            Text(L10n.tr("help.feedback.title"))
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.text)

                            Text(L10n.tr("help.feedback.subtitle"))
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(AppTheme.muted)

                            TextField(L10n.tr("help.feedback.subject.placeholder"), text: $subject)
                                .appInputChrome()

                            TextField(L10n.tr("help.feedback.message.placeholder"), text: $suggestion, axis: .vertical)
                                .lineLimit(5 ... 9)
                                .appInputChrome()

                            TextField(L10n.tr("help.feedback.contact.placeholder"), text: $contactEmail)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .appInputChrome()

                            Button(L10n.tr("help.feedback.send")) {
                                sendSuggestion()
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }

                        Spacer(minLength: 10)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(L10n.tr("tab.help"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $isPresentingMailComposer) {
#if canImport(MessageUI)
            SupportMailComposeSheet(
                recipient: supportEmail,
                subject: sanitizedSubject,
                body: emailBody,
                onResult: handleMailComposerResult
            )
#else
            EmptyView()
#endif
        }
        .alert(L10n.tr("common.notice"), isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button(L10n.tr("common.ok"), role: .cancel) {
                alertMessage = nil
            }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var sanitizedSubject: String {
        subject.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sanitizedSuggestion: String {
        suggestion.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sanitizedContactEmail: String {
        contactEmail.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var emailBody: String {
        let contactValue = sanitizedContactEmail.isEmpty ? L10n.tr("help.feedback.mail.body.noContact") : sanitizedContactEmail
        let details = [
            "\(L10n.tr("help.feedback.mail.body.device")): \(deviceSummary)",
            "\(L10n.tr("help.feedback.mail.body.system")): \(systemSummary)",
            "\(L10n.tr("help.feedback.mail.body.appVersion")): \(appVersionSummary)",
            "\(L10n.tr("help.feedback.mail.body.language")): \(Locale.current.identifier)",
            "\(L10n.tr("help.feedback.mail.body.time")): \(timestampSummary)"
        ].joined(separator: "\n")

        return "\(L10n.tr("help.feedback.mail.body.suggestion")):\n\(sanitizedSuggestion)\n\n\(L10n.tr("help.feedback.mail.body.contact")): \(contactValue)\n\n\(L10n.tr("help.feedback.mail.body.details")):\n\(details)"
    }

    private var deviceSummary: String {
        #if canImport(UIKit)
        UIDevice.current.model
        #else
        ProcessInfo.processInfo.hostName
        #endif
    }

    private var systemSummary: String {
        #if canImport(UIKit)
        "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        #else
        ProcessInfo.processInfo.operatingSystemVersionString
        #endif
    }

    private var appVersionSummary: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return "\(version) (\(build))"
    }

    private var timestampSummary: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }

    private func sendSuggestion() {
        guard !sanitizedSubject.isEmpty, !sanitizedSuggestion.isEmpty else {
            alertMessage = L10n.tr("help.feedback.error.required")
            return
        }

        if !sanitizedContactEmail.isEmpty, !isValidEmail(sanitizedContactEmail) {
            alertMessage = L10n.tr("help.feedback.error.email")
            return
        }

        if canUseMailComposer {
            isPresentingMailComposer = true
            return
        }

        guard let mailURL = mailtoURL() else {
            alertMessage = L10n.tr("help.feedback.error.sendUnavailable")
            return
        }

        openURL(mailURL) { accepted in
            if accepted {
                clearForm()
                alertMessage = L10n.tr("help.feedback.success")
            } else {
                alertMessage = L10n.tr("help.feedback.error.sendUnavailable")
            }
        }
    }

    private func mailtoURL() -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: sanitizedSubject),
            URLQueryItem(name: "body", value: emailBody)
        ]
        return components.url
    }

    private var canUseMailComposer: Bool {
        #if canImport(MessageUI)
        MFMailComposeViewController.canSendMail()
        #else
        false
        #endif
    }

    #if canImport(MessageUI)
    private func handleMailComposerResult(_ result: Result<MFMailComposeResult, Error>) {
        switch result {
        case let .success(mailResult):
            switch mailResult {
            case .sent:
                clearForm()
                alertMessage = L10n.tr("help.feedback.success")
            case .failed:
                alertMessage = L10n.tr("help.feedback.error.sendFailed")
            default:
                break
            }
        case .failure:
            alertMessage = L10n.tr("help.feedback.error.sendFailed")
        }
    }
    #endif

    private func clearForm() {
        subject = ""
        suggestion = ""
        contactEmail = ""
    }

    private func isValidEmail(_ value: String) -> Bool {
        guard !value.contains(" ") else { return false }
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        let localPart = String(parts[0])
        let domainPart = String(parts[1])
        guard !localPart.isEmpty, !domainPart.isEmpty else { return false }
        return domainPart.contains(".")
    }
}

#if canImport(MessageUI)
private struct SupportMailComposeSheet: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String
    let onResult: (Result<MFMailComposeResult, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.setToRecipients([recipient])
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)
        controller.mailComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        private let onResult: (Result<MFMailComposeResult, Error>) -> Void

        init(onResult: @escaping (Result<MFMailComposeResult, Error>) -> Void) {
            self.onResult = onResult
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            defer { controller.dismiss(animated: true) }

            if let error {
                onResult(.failure(error))
            } else {
                onResult(.success(result))
            }
        }
    }
}
#endif
