import Combine
import Foundation
import LocalAuthentication
import SwiftUI

@MainActor
final class AppLockService: ObservableObject {
    private static let enabledKey = "appLockEnabled"

    @AppStorage(AppLockService.enabledKey) var isEnabled: Bool = false
    @Published private(set) var isLocked: Bool = false

    /// Persistent context that tracks biometric failure state.
    /// When biometrics fail on this context, the next evaluatePolicy call
    /// on it will present the passcode fallback.
    private var authContext: LAContext?
    private var isAuthenticating = false

    init() {
        if UserDefaults.standard.bool(forKey: Self.enabledKey) {
            isLocked = true
        }
    }

    // MARK: - Biometry Info

    var biometryType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    var biometryLabel: String {
        switch biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        @unknown default:
            return "Biometrics"
        }
    }

    var biometryIconName: String {
        switch biometryType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        @unknown default:
            return "lock.fill"
        }
    }

    var isBiometryAvailable: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    // MARK: - Lock / Unlock

    func lock() {
        guard isEnabled else { return }
        isLocked = true
        // Reset context so next unlock starts fresh with biometrics
        authContext = nil
    }

    func authenticate() async -> Bool {
        guard !isAuthenticating else { return false }
        isAuthenticating = true
        defer { isAuthenticating = false }

        let context = authContext ?? LAContext()
        context.localizedCancelTitle = L10n.tr("common.cancel")
        authContext = context

        let reason = L10n.tr("lock.authReason")

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
            do {
                let biometricSuccess = try await context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: reason
                )
                if biometricSuccess {
                    isLocked = false
                    authContext = nil
                    return true
                }
            } catch let error as LAError where error.code == .userCancel {
                return false
            } catch {
                // Fall through to passcode-capable policy below.
            }
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            if success {
                isLocked = false
                authContext = nil
            }
            return success
        } catch let error as LAError {
            if error.code == .userCancel {
                return false
            }
            return false
        } catch {
            return false
        }
    }

    /// Performs a one-time authentication check when toggling the setting ON.
    /// Returns `true` if the user successfully authenticates.
    func verifyCanAuthenticate() async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = L10n.tr("common.cancel")

        let reason = L10n.tr("lock.verifyReason")

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
        } catch {
            return false
        }
    }
}
