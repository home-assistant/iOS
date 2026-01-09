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

    /// Authenticate user with biometrics or PIN
    /// - Parameter reason: The reason shown to user for authentication
    /// - Returns: True if authentication succeeded
    public func authenticate(reason: String = "Authenticate to exit kiosk mode") async -> Bool {
        // First try biometric if enabled and available
        if settings.allowBiometricExit && isBiometryAvailable {
            let biometricResult = await authenticateWithBiometrics(reason: reason)
            if biometricResult {
                isAuthenticated = true
                return true
            }
        }

        // If biometric fails or not available, we need PIN (handled by caller)
        return false
    }

    /// Authenticate specifically with biometrics
    private func authenticateWithBiometrics(reason: String) async -> Bool {
        let context = LAContext()

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )

            if success {
                Current.Log.info("Biometric authentication successful")
                return true
            }
        } catch {
            Current.Log.warning("Biometric authentication failed: \(error.localizedDescription)")
        }

        return false
    }

    /// Validate PIN entry
    /// - Parameter pin: The PIN to validate
    /// - Returns: True if PIN is correct
    public func validatePIN(_ pin: String) -> Bool {
        guard !settings.exitPIN.isEmpty else {
            // No PIN required
            isAuthenticated = true
            return true
        }

        if pin == settings.exitPIN {
            isAuthenticated = true
            Current.Log.info("PIN authentication successful")
            return true
        }

        Current.Log.warning("PIN authentication failed")
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

// MARK: - PIN Entry View

import SwiftUI

public struct PINEntryView: View {
    @Binding var isPresented: Bool
    let onAuthenticated: () -> Void

    @State private var enteredPIN = ""
    @State private var showError = false
    @State private var attemptCount = 0

    private let maxAttempts = 5
    private let settings = KioskModeManager.shared.settings

    public init(isPresented: Binding<Bool>, onAuthenticated: @escaping () -> Void) {
        _isPresented = isPresented
        self.onAuthenticated = onAuthenticated
    }

    public var body: some View {
        VStack(spacing: 30) {
            // Title
            Text("Enter PIN")
                .font(.title)
                .fontWeight(.semibold)

            // PIN dots display
            HStack(spacing: 20) {
                ForEach(0..<settings.exitPIN.count, id: \.self) { index in
                    Circle()
                        .fill(index < enteredPIN.count ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 20, height: 20)
                        .accessibilityLabel("PIN digit \(index + 1): \(index < enteredPIN.count ? "entered" : "empty")")
                }
            }
            .padding()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("PIN entry: \(enteredPIN.count) of \(settings.exitPIN.count) digits entered")

            // Error message
            if showError {
                Text("Incorrect PIN")
                    .foregroundColor(.red)
                    .font(.caption)
            }

            // Remaining attempts warning
            if attemptCount >= 3 {
                Text("\(maxAttempts - attemptCount) attempts remaining")
                    .foregroundColor(.orange)
                    .font(.caption)
            }

            // Number pad
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 20) {
                ForEach(1...9, id: \.self) { number in
                    numberButton(String(number))
                }

                // Bottom row
                biometricButton
                numberButton("0")
                deleteButton
            }
            .padding()

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
            attemptBiometric()
        }
    }

    private func numberButton(_ digit: String) -> some View {
        Button {
            addDigit(digit)
        } label: {
            Text(digit)
                .font(.title)
                .fontWeight(.medium)
                .frame(width: 70, height: 70)
                .background(Color(.secondarySystemBackground))
                .clipShape(Circle())
        }
        .disabled(enteredPIN.count >= settings.exitPIN.count)
        .accessibilityLabel("Number \(digit)")
        .accessibilityHint("Enter digit \(digit)")
    }

    @ViewBuilder
    private var biometricButton: some View {
        if SecurityManager.shared.isBiometryAvailable && settings.allowBiometricExit {
            Button {
                attemptBiometric()
            } label: {
                Image(systemName: biometricIcon)
                    .font(.title)
                    .frame(width: 70, height: 70)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Authenticate with \(SecurityManager.shared.biometryName)")
            .accessibilityHint("Use biometric authentication to exit kiosk mode")
        } else {
            Color.clear
                .frame(width: 70, height: 70)
                .accessibilityHidden(true)
        }
    }

    private var biometricIcon: String {
        switch SecurityManager.shared.biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        default: return "lock"
        }
    }

    private var deleteButton: some View {
        Button {
            deleteDigit()
        } label: {
            Image(systemName: "delete.left")
                .font(.title2)
                .frame(width: 70, height: 70)
                .background(Color(.secondarySystemBackground))
                .clipShape(Circle())
        }
        .disabled(enteredPIN.isEmpty)
        .accessibilityLabel("Delete")
        .accessibilityHint("Remove the last entered digit")
    }

    private func addDigit(_ digit: String) {
        guard enteredPIN.count < settings.exitPIN.count else { return }

        enteredPIN += digit
        showError = false

        // Check if PIN is complete
        if enteredPIN.count == settings.exitPIN.count {
            validatePIN()
        }
    }

    private func deleteDigit() {
        guard !enteredPIN.isEmpty else { return }
        enteredPIN.removeLast()
        showError = false
    }

    private func validatePIN() {
        if SecurityManager.shared.validatePIN(enteredPIN) {
            isPresented = false
            onAuthenticated()
        } else {
            enteredPIN = ""
            showError = true
            attemptCount += 1

            // Haptic feedback for error
            TouchFeedbackManager.shared.playFeedback(for: .error)

            // Lock out after max attempts
            if attemptCount >= maxAttempts {
                // Could implement lockout period here
                isPresented = false
            }
        }
    }

    private func attemptBiometric() {
        guard SecurityManager.shared.isBiometryAvailable && settings.allowBiometricExit else { return }

        Task {
            let success = await SecurityManager.shared.authenticate(reason: "Exit kiosk mode")
            if success {
                await MainActor.run {
                    isPresented = false
                    onAuthenticated()
                }
            }
        }
    }
}
