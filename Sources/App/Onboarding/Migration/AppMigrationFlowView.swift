import Shared
import SwiftUI

/// The new app's transfer step inside onboarding: intro, overview, then whatever the coordinator is
/// doing until the setup has been applied.
struct AppMigrationFlowView: View {
    @ObservedObject var coordinator: AppMigrationCoordinator = .shared
    @State private var showsOverview = false
    @State var permissionsToAllow: [SensorPermission]?
    let skipAction: () -> Void
    let finishAction: () -> Void

    /// The permissions screen only earns its place when something can still be asked: what iOS has
    /// already settled for this app, or cannot offer on this device, is left out. Notifications are
    /// kept because their status is only known asynchronously.
    static func permissionsStillToAsk(from granted: [SensorPermission]) -> [SensorPermission] {
        let requester = SensorPermissionRequester.shared
        return granted.filter { permission in
            guard requester.isAvailable(permission) else { return false }
            return permission == .notification || requester.status(for: permission) == .notDetermined
        }
    }

    /// Offered while the previous app is still around to be wiped.
    private var eraseAction: (() -> Void)? {
        guard coordinator.isPreviousAppInstalled else { return nil }
        return { coordinator.erasePreviousApp() }
    }

    /// Leaves the success screen: straight out when nothing is left to ask, otherwise through the
    /// permissions screen.
    func finishAfterSuccess(_ summary: AppMigrationSummary) {
        let pending = Self.permissionsStillToAsk(from: summary.grantedPermissions)
        if pending.isEmpty {
            coordinator.finishImport()
            finishAction()
        } else {
            permissionsToAllow = pending
        }
    }

    var body: some View {
        if let permissionsToAllow {
            AppMigrationPermissionsView(permissions: permissionsToAllow) {
                coordinator.finishImport()
                finishAction()
            }
            .navigationBarBackButtonHidden(true)
            .onChange(of: coordinator.completedSummary) { summary in
                if summary == nil {
                    self.permissionsToAllow = nil
                }
            }
        } else if let summary = coordinator.completedSummary {
            AppMigrationSuccessView(
                summary: summary,
                previousAppErased: coordinator.previousAppErased,
                eraseAction: eraseAction
            ) {
                finishAfterSuccess(summary)
            }
            .navigationBarBackButtonHidden(true)
        } else if let state = coordinator.importState {
            AppMigrationImportView(
                state: state,
                openPreviousAppAction: coordinator.openPreviousApp,
                retryAction: coordinator.startImport,
                cancelAction: {
                    coordinator.cancelImport()
                    skipAction()
                }
            )
            .navigationBarBackButtonHidden(true)
        } else if showsOverview {
            AppMigrationOverviewView {
                AppMigrationHaptics.tap()
                coordinator.startImport()
            }
        } else {
            AppMigrationIntroView(
                continueAction: {
                    AppMigrationHaptics.tap()
                    showsOverview = true
                },
                skipAction: skipAction
            )
        }
    }
}

#Preview {
    NavigationStack {
        AppMigrationFlowView(skipAction: {}, finishAction: {})
    }
}
