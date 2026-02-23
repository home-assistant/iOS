import Shared
import SwiftUI
import UIKit

// MARK: - Onboarding & Security Level

extension WebViewController {
    /// If user has not chosen 'Most secure' or 'Less secure' local access yet, this triggers a screen for decision
    func checkForLocalSecurityLevelDecisionNeeded() {
        if Current.location.permissionStatus == .notDetermined, server.info.connection.hasNonHTTPSURLOption {
            Current.Log.verbose("User has not decided location permission yet")
            showOnboardingPermissions(steps: OnboardingPermissionsNavigationViewModel.StepID.updateLocationPermission)
        } else if server.info.connection.connectionAccessSecurityLevel == .undefined {
            Current.Log.verbose("User has not decided local access security level yet")
            showOnboardingPermissions(
                steps: OnboardingPermissionsNavigationViewModel.StepID
                    .updateLocalAccessSecurityLevelPreference
            )
        } else {
            Current.Log
                .verbose(
                    "User decided \(server.info.connection.connectionAccessSecurityLevel) for local access security level"
                )
        }
    }

    func showOnboardingPermissions(steps: [OnboardingPermissionsNavigationViewModel.StepID]) {
        let controller = NavigationView {
            OnboardingPermissionsNavigationView(onboardingServer: server, steps: steps)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        CloseButton { [weak self] in
                            self?.dismiss(animated: true)
                        }
                    }
                }
                .onDisappear { [weak self] in
                    self?.refresh()
                }
        }.navigationViewStyle(.stack).embeddedInHostingController()

        // Prevent controller on being dismissed on swipe down
        controller.isModalInPresentation = true
        controller.view.tag = WebViewControllerOverlayedViewTags.onboardingPermissions.rawValue
        presentOverlayController(controller: controller, animated: true)
    }
}
