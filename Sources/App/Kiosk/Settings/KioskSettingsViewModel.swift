import AVFoundation
import LocalAuthentication
import Shared
import SwiftUI

@MainActor
public final class KioskSettingsViewModel: ObservableObject {
    @Published public var settings: KioskSettings
    @Published public var isAuthenticated = false
    @Published public var showingAuthError = false
    @Published public var authErrorMessage = ""
    @Published public var showingCameraPermissionDenied = false

    private let manager: KioskModeManager
    private let onDismiss: (() -> Void)?

    /// Whether authentication is required to access settings
    var authRequired: Bool {
        manager.isKioskModeActive && manager.settings.requireDeviceAuthentication
    }

    var isKioskModeActive: Bool {
        manager.isKioskModeActive
    }

    init(manager: KioskModeManager = .shared, onDismiss: (() -> Void)? = nil) {
        self.manager = manager
        self.onDismiss = onDismiss
        self.settings = manager.settings
    }

    func onAppear() {
        manager.pauseIdleTimer()
        if authRequired {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.authenticateForSettings()
            }
        } else {
            isAuthenticated = true
        }
    }

    func onDisappear() {
        manager.resumeIdleTimer()
    }

    func dismiss(using environmentDismiss: DismissAction) {
        if let onDismiss {
            onDismiss()
        } else {
            environmentDismiss()
        }
    }

    func settingsChanged() {
        if isAuthenticated || !authRequired {
            manager.updateSettings(settings)
        }
    }

    func enableKioskMode() {
        manager.enableKioskMode()
    }

    func attemptKioskExit() {
        let authSettings = manager.settings
        guard authSettings.requireDeviceAuthentication else {
            manager.disableKioskMode()
            return
        }

        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            manager.disableKioskMode()
            return
        }

        let reason = L10n.Kiosk.AuthError.reason
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
            DispatchQueue.main.async { [weak self] in
                if success {
                    self?.manager.disableKioskMode()
                } else if let authError = authError as? LAError {
                    switch authError.code {
                    case .userCancel, .appCancel:
                        break
                    default:
                        self?.authErrorMessage = authError.localizedDescription
                        self?.showingAuthError = true
                    }
                }
            }
        }
    }

    func authenticateForSettings() {
        let context = LAContext()
        var error: NSError?
        let authSettings = manager.settings

        guard authSettings.requireDeviceAuthentication else {
            isAuthenticated = true
            return
        }

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            isAuthenticated = true
            return
        }

        let reason = L10n.Kiosk.AuthError.reason
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
            DispatchQueue.main.async { [weak self] in
                if success {
                    self?.isAuthenticated = true
                } else if let authError = authError as? LAError {
                    switch authError.code {
                    case .userCancel, .appCancel:
                        break
                    default:
                        self?.authErrorMessage = authError.localizedDescription
                        self?.showingAuthError = true
                    }
                }
            }
        }
    }

    func handleAuthErrorDismissed(using environmentDismiss: DismissAction) {
        if manager.isKioskModeActive {
            dismiss(using: environmentDismiss)
        }
    }

    /// Toggle camera motion detection. Turning it on requests camera authorization
    /// first so the underlying detector can actually start; on denial we revert
    /// the toggle and surface an alert that deep-links to iOS Settings.
    func setCameraMotionEnabled(_ enabled: Bool) {
        guard enabled else {
            settings.cameraMotionEnabled = false
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            settings.cameraMotionEnabled = true
        case .notDetermined:
            Task { [weak self] in
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                await MainActor.run {
                    if granted {
                        self?.settings.cameraMotionEnabled = true
                    } else {
                        self?.showingCameraPermissionDenied = true
                    }
                }
            }
        case .denied, .restricted:
            showingCameraPermissionDenied = true
        @unknown default:
            showingCameraPermissionDenied = true
        }
    }
}
