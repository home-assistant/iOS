import PromiseKit
import Shared
import SwiftUI
import UIKit

// MARK: - Onboarding & Security Level

extension WebViewController {
    /// If user has not chosen 'Most secure' or 'Less secure' local access yet, this triggers a screen for decision
    func checkForLocalSecurityLevelDecisionNeeded() {
        let connection = server.info.connection

        // Declining to share location during onboarding never shows the iOS permission dialog, so the
        // system status stays `.notDetermined` even though the user already decided — an explicit
        // `.never` privacy setting counts as a decision and must not re-trigger the flow.
        let userDeclinedLocationSharing = server.info.setting(for: .locationPrivacy) == .never

        if Current.location.permissionStatus == .notDetermined, !userDeclinedLocationSharing,
           connection.hasNonHTTPSURLOptions {
            Current.Log.verbose("User has not decided location permission yet")
            showOnboardingPermissions(steps: OnboardingPermissionsNavigationViewModel.StepID.updateLocationPermission)
        } else if connection.connectionAccessSecurityLevel == .undefined, !connection.hasOnlyHTTPSURLOptions {
            Current.Log.verbose("User has not decided local access security level yet")
            showOnboardingPermissions(
                steps: OnboardingPermissionsNavigationViewModel.StepID
                    .updateLocalAccessSecurityLevelPreference
            )
        } else if connection.hasOnlyHTTPSURLOptions {
            Current.Log.verbose("Skipping local access security level decision because all configured URLs use HTTPS")
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
