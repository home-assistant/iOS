import Foundation
import LocalAuthentication
import UIKit

public protocol BiometricsAuthenticationServiceProtocol {
    func checkForBiometrics(controller: UIViewController)
    func protectAppIfNeeded(controller: UIViewController, completion: (() -> Void)?)
}

class BiometricsAuthenticationService: BiometricsAuthenticationServiceProtocol {
    private var context: LAContext?

    private var overlayViewController: BiometricsAuthenticationViewController?

    private var shouldAllowMacToAuthenticate = true

    init() {
        #if targetEnvironment(macCatalyst)
        if #available(iOS 13.0, *) {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(allowReauthenticate),
                name: UIScene.didEnterBackgroundNotification,
                object: nil
            )
        } else {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(allowReauthenticate),
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )
        }
        #endif
    }

    /// Adds the protection overlay and tries to authenticate
    func checkForBiometrics(controller: UIViewController) {
        guard context == nil else { return }
        protectAppIfNeeded(controller: controller) { [weak self] in
            if Current.settingsStore.biometricsRequired {
                #if targetEnvironment(macCatalyst)
                guard self?.shouldAllowMacToAuthenticate ?? false else { return }
                #endif
                self?.authenticate()
            }
        }
    }

    /// Adds the protection overlay
    func protectAppIfNeeded(controller: UIViewController, completion: (() -> Void)?) {
        if Current.settingsStore.biometricsRequired {
            addBiometricOverlayProtection(controller: controller) {
                completion?()
            }
        } else {
            removeProtectionOverlay()
        }
    }

    #if targetEnvironment(macCatalyst)
    /// This avoids macOS going on loop between enter background and enter foreground while trying to authenticate
    @objc private func allowReauthenticate() {
        shouldAllowMacToAuthenticate = true
    }
    #endif

    private func authenticate() {
        var error: NSError?
        context?.invalidate()
        context = LAContext()
        if context?.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) ?? false {
            authenticate(policy: .deviceOwnerAuthenticationWithBiometrics)
        } else if context?.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) ?? false {
            authenticate(policy: .deviceOwnerAuthentication)
        } else {
            Current.Log
                .error(
                    "Failed to authenticate with biometrics, user context can't evaluate policy for device ownership"
                )
        }
    }

    private func removeProtectionOverlay() {
        DispatchQueue.main.async { [weak self] in
            self?.overlayViewController?.dismiss(animated: true) {
                self?.overlayViewController = nil
            }
        }
    }

    private func authenticate(policy: LAPolicy) {
        context?
            .evaluatePolicy(
                policy,
                localizedReason: L10n.SettingsDetails.General.Security
                    .authenticationPolicy
            ) { [weak self] authorized, error in
                self?.didFinishAuthentication(authorized: authorized)

                if let error {
                    Current.Log.error(["Failed to evaluate policy for authentication": error.localizedDescription])
                }
            }
    }

    private func didFinishAuthentication(authorized: Bool) {
        if authorized {
            #if targetEnvironment(macCatalyst)
            shouldAllowMacToAuthenticate = false
            #endif
            context?.invalidate()
            context = nil
            removeProtectionOverlay()
        } else {
            overlayViewController?.updateUnlockButtonVisibility(visible: true)
        }
    }

    private func addBiometricOverlayProtection(controller: UIViewController, completion: @escaping () -> Void) {
        guard overlayViewController == nil else {
            completion()
            return
        }
        overlayViewController = BiometricsAuthenticationViewController()
        overlayViewController?.modalPresentationStyle = .overCurrentContext
        overlayViewController?.delegate = self
        guard let overlayViewController = overlayViewController else { return }

        DispatchQueue.main.async {
            controller.present(overlayViewController, animated: false) {
                completion()
            }
        }
    }
}

extension BiometricsAuthenticationService: BiometricsAuthenticationViewControllerDelegate {
    func didTapUnlock() {
        authenticate()
    }
}
