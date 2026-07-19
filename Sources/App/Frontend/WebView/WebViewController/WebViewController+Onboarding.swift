import CoreLocation
import PromiseKit
import Shared
import SwiftUI
import UIKit

// MARK: - Onboarding & Security Level

extension WebViewController {
    /// The permission steps to force a decision for, or `nil` when every decision has been made.
    /// Declining to share location during onboarding never shows the iOS permission dialog, so the
    /// system status stays `.notDetermined` even though the user already decided — an explicit
    /// `.never` privacy setting counts as a decision and must not re-trigger the flow.
    static func localSecurityLevelDecisionSteps(
        connection: ConnectionInfo,
        locationPermissionStatus: CLAuthorizationStatus,
        userDeclinedLocationSharing: Bool
    ) -> [OnboardingPermissionsNavigationViewModel.StepID]? {
        if locationPermissionStatus == .notDetermined, !userDeclinedLocationSharing,
           connection.hasNonHTTPSURLOptions {
            return OnboardingPermissionsNavigationViewModel.StepID.updateLocationPermission
        } else if connection.connectionAccessSecurityLevel == .undefined, !connection.hasOnlyHTTPSURLOptions {
            return OnboardingPermissionsNavigationViewModel.StepID.updateLocalAccessSecurityLevelPreference
        } else {
            return nil
        }
    }

    /// If user has not chosen 'Most secure' or 'Less secure' local access yet, this triggers a screen for decision
    func checkForLocalSecurityLevelDecisionNeeded() {
        let connection = server.info.connection
        let steps = Self.localSecurityLevelDecisionSteps(
            connection: connection,
            locationPermissionStatus: Current.location.permissionStatus,
            userDeclinedLocationSharing: server.info.setting(for: .locationPrivacy) == .never
        )

        if let steps {
            Current.Log.verbose("Local security level decision needed, requesting steps: \(steps.map(\.rawValue))")
            showOnboardingPermissions(steps: steps)
        } else {
            Current.Log
                .verbose(
                    "No local security level decision needed, level: \(connection.connectionAccessSecurityLevel)"
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
