import Foundation
import LocalAuthentication
import SwiftUI
import UIKit

public protocol BiometricsAuthenticationServiceProtocol {
    func checkForBiometrics(controller: UIViewController)
    func protectAppIfNeeded(controller: UIViewController, completion: (() -> Void)?)
}

final class BiometricsAuthenticationService: BiometricsAuthenticationServiceProtocol {
    private var context: LAContext?
    private var window: UIWindow?
    private var previousRootViewController: UIViewController?

    /// Adds the protection overlay and tries to authenticate
    func checkForBiometrics(controller: UIViewController) {
        // Means biometrics lock is on top
        if let previousRootViewController {
            authenticate()
            return
        }

        guard context == nil else { return }
        protectAppIfNeeded(controller: controller) { [weak self] in
            if Current.settingsStore.biometricsRequired {
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
        guard let window, let previousRootViewController else { return }
        DispatchQueue.main.async { [weak self] in
            window.rootViewController = previousRootViewController
            self?.previousRootViewController = nil
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
            context?.invalidate()
            context = nil
            removeProtectionOverlay()
        }
    }

    private func addBiometricOverlayProtection(controller: UIViewController, completion: @escaping () -> Void) {
        guard #available(iOS 13.0, *) else { return }

        let overlayController = UIHostingController(rootView: BiometricsView.build(delegate: self))
        overlayController.modalPresentationStyle = .overCurrentContext

        guard let window = controller.view.window,
              previousRootViewController == nil else { return }

        self.window = window

        previousRootViewController = window.rootViewController
        window.rootViewController = overlayController
        window.windowLevel = UIWindow.Level(UIWindow.Level.alert.rawValue + 1)
    }
}

extension BiometricsAuthenticationService: BiometricsViewModelDelegate {
    func didRequestUnlock() {
        authenticate()
    }
}
