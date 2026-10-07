import PromiseKit
import Shared
import SwiftUI
import UIKit

// MARK: - Onboarding & Security Level

extension WebViewController {
    /// If user has not chosen 'Most secure' or 'Less secure' local access yet, this triggers a screen for decision
    func checkForLocalSecurityLevelDecisionNeeded() {
        let connection = server.info.connection

        // Local network configuration is only needed when the server can exclusively be
        // reached over non-HTTPS URLs; with an HTTPS URL available the active URL always
        // has a secure option to use
        guard !connection.hasHTTPSURLOption else {
            if connection.connectionAccessSecurityLevel == .undefined {
                Current.Log.verbose("Auto selecting most secure local access level because an HTTPS URL is available")
                server.update { info in
                    info.connection.connectionAccessSecurityLevel = .mostSecure
                }
            } else {
                Current.Log.verbose("Skipping local access security level decision because an HTTPS URL is available")
            }
            return
        }

        if Current.location.permissionStatus() == .notDetermined, connection.hasNonHTTPSURLOptions {
            Current.Log.verbose("User has not decided location permission yet")
            showOnboardingPermissions(steps: OnboardingPermissionsNavigationViewModel.StepID.updateLocationPermission)
        } else if connection.connectionAccessSecurityLevel == .undefined {
            Current.Log.verbose("User has not decided local access security level yet")
            showOnboardingPermissions(
                steps: OnboardingPermissionsNavigationViewModel.StepID
                    .updateLocalAccessSecurityLevelPreference
            )
        } else {
            Current.Log
                .verbose(
                    "User decided \(connection.connectionAccessSecurityLevel) for local access security level"
                )
        }
    }

    func showOnboardingPermissions(steps: [OnboardingPermissionsNavigationViewModel.StepID]) {
        // Present the forced decision as a full-screen cover via `ContainerView` (SwiftUI). It can't be
        // swiped away, has a close button, and the web view refreshes when it's dismissed.
        Current.sceneManager.appCoordinator.done { [server] in
            $0.showOnboardingPermissions(server: server, steps: steps)
        }
    }
}
