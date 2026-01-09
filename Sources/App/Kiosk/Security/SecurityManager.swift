import LocalAuthentication
import Shared
import UIKit

// MARK: - Security Manager

/// Manages biometric authentication and security features for kiosk mode
@MainActor
public final class SecurityManager: ObservableObject {
    // MARK: - Singleton

    public static let shared = SecurityManager()

    // MARK: - Published Properties

    @Published public private(set) var isAuthenticated = false
    @Published public private(set) var biometryType: LABiometryType = .none
    @Published public private(set) var isBiometryAvailable = false
    @Published public private(set) var isLocked = false

    // MARK: - Private Properties

    private let context = LAContext()
    private var settings: KioskSettings { KioskModeManager.shared.settings }

    // MARK: - Initialization

    private init() {
        checkBiometryAvailability()
    }

    // MARK: - Biometry Check

    /// Check what biometric authentication is available
    public func checkBiometryAvailability() {
        var error: NSError?
        let available = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)

        isBiometryAvailable = available
        biometryType = context.biometryType

        if let error {
            Current.Log.warning("Biometry not available: \(error.localizedDescription)")
        }
    }

    /// Get human-readable name for biometry type
    public var biometryName: String {
        switch biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        case .none: return "None"
        @unknown default: return "Biometric"
        }
    }

    // MARK: - Authentication

    /// Authenticate user with biometrics or device passcode
    /// - Parameter reason: The reason shown to user for authentication
    /// - Returns: True if authentication succeeded
    public func authenticate(reason: String = "Authenticate to exit kiosk mode") async -> Bool {
        let context = LAContext()

        // Determine which policy to use based on settings
        let policy: LAPolicy
        if settings.allowBiometricExit && settings.allowDevicePasscodeExit {
            // Allow biometrics with passcode fallback
            policy = .deviceOwnerAuthentication
        } else if settings.allowBiometricExit {
            // Biometrics only
            policy = .deviceOwnerAuthenticationWithBiometrics
        } else if settings.allowDevicePasscodeExit {
            // Device passcode only (rare case)
            policy = .deviceOwnerAuthentication
        } else {
            // No authentication configured - allow exit
            Current.Log.warning("No authentication method configured for kiosk exit")
            isAuthenticated = true
            return true
        }

        do {
            let success = try await context.evaluatePolicy(policy, localizedReason: reason)
            if success {
                isAuthenticated = true
                Current.Log.info("Authentication successful")
                return true
            }
        } catch {
            Current.Log.warning("Authentication failed: \(error.localizedDescription)")
        }

        return false
    }

    /// Reset authentication state
    public func resetAuthentication() {
        isAuthenticated = false
    }

    // MARK: - Remote Lock/Unlock

    /// Lock the device remotely (from HA command)
    public func remoteLock() {
        guard settings.remoteLockEnabled else {
            Current.Log.warning("Remote lock is disabled")
            return
        }

        isLocked = true
        KioskModeManager.shared.updateSetting(\.isRemotelyLocked, to: true)
        Current.Log.info("Device remotely locked")

        // Notify sensor provider
        NotificationCenter.default.post(name: .kioskLockStateChanged, object: nil)
    }

    /// Unlock the device remotely (from HA command)
    public func remoteUnlock() {
        guard settings.remoteLockEnabled else {
            Current.Log.warning("Remote unlock is disabled")
            return
        }

        isLocked = false
        KioskModeManager.shared.updateSetting(\.isRemotelyLocked, to: false)
        Current.Log.info("Device remotely unlocked")

        // Notify sensor provider
        NotificationCenter.default.post(name: .kioskLockStateChanged, object: nil)
    }

    /// Check if exit from kiosk mode should be blocked
    public var shouldBlockExit: Bool {
        if isLocked { return true }
        if settings.isRemotelyLocked { return true }
        return false
    }

    // MARK: - Device Owner Authentication (PIN or Biometric)

    /// Check if device passcode is set
    public var isDevicePasscodeSet: Bool {
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        return canEvaluate
    }

    /// Authenticate with device passcode as fallback
    /// - Returns: (success, errorMessage) - success if authenticated, errorMessage if failed
    public func authenticateWithDevicePasscode(reason: String = "Enter device passcode") async -> (success: Bool, error: String?) {
        let context = LAContext()

        // First check if passcode is even set
        var checkError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &checkError) else {
            let message = checkError?.localizedDescription ?? "Device passcode is not set"
            Current.Log.warning("Device passcode not available: \(message)")
            return (false, "Device passcode is not set. Please set a passcode in iOS Settings, or use a different exit method.")
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )

            if success {
                isAuthenticated = true
                Current.Log.info("Device passcode authentication successful")
                return (true, nil)
            }
        } catch let error as LAError {
            switch error.code {
            case .userCancel:
                return (false, nil) // User cancelled, no error message needed
            case .passcodeNotSet:
                return (false, "Device passcode is not set. Please set a passcode in iOS Settings, or use a different exit method.")
            default:
                Current.Log.warning("Device passcode authentication failed: \(error.localizedDescription)")
                return (false, error.localizedDescription)
            }
        } catch {
            Current.Log.warning("Device passcode authentication failed: \(error.localizedDescription)")
            return (false, error.localizedDescription)
        }

        return (false, nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let kioskLockStateChanged = Notification.Name("kioskLockStateChanged")
}

// MARK: - Authentication View

import SwiftUI

/// Simple authentication view that triggers device authentication (Face ID/Touch ID/Passcode)
public struct AuthenticationView: View {
    @Binding var isPresented: Bool
    let onAuthenticated: () -> Void

    @State private var isAuthenticating = false
    @State private var authenticationFailed = false

    public init(isPresented: Binding<Bool>, onAuthenticated: @escaping () -> Void) {
        _isPresented = isPresented
        self.onAuthenticated = onAuthenticated
    }

    public var body: some View {
        VStack(spacing: 30) {
            // Icon
            Image(systemName: authenticationIcon)
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            // Title
            Text("Authentication Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Authenticate to exit kiosk mode")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if authenticationFailed {
                Text("Authentication failed. Please try again.")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            // Authenticate button
            Button {
                authenticate()
            } label: {
                HStack {
                    Image(systemName: authenticationIcon)
                    Text("Authenticate")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.accentColor)
                .cornerRadius(12)
            }
            .disabled(isAuthenticating)
            .padding(.horizontal)

            // Cancel button
            Button("Cancel") {
                isPresented = false
            }
            .foregroundColor(.secondary)
        }
        .padding(40)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(radius: 20)
        .onAppear {
            // Auto-trigger authentication on appear
            authenticate()
        }
    }

    private var authenticationIcon: String {
        switch SecurityManager.shared.biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        default: return "lock.fill"
        }
    }

    private func authenticate() {
        isAuthenticating = true
        authenticationFailed = false

        Task {
            let success = await SecurityManager.shared.authenticate(reason: "Exit kiosk mode")
            await MainActor.run {
                isAuthenticating = false
                if success {
                    isPresented = false
                    onAuthenticated()
                } else {
                    authenticationFailed = true
                    TouchFeedbackManager.shared.playFeedback(for: .error)
                }
            }
        }
    }
}
