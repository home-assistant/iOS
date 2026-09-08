import Shared
import SwiftUI

/// The new app's transfer step inside onboarding: intro, overview, then whatever the coordinator is
/// doing until the setup has been applied.
struct AppMigrationFlowView: View {
    @ObservedObject private var coordinator = AppMigrationCoordinator.shared
    @State private var showsOverview = false
    @State private var permissionsToAllow: [SensorPermission]?
    let skipAction: () -> Void
    let finishAction: () -> Void

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
            AppMigrationCompleteView(summary: summary) {
                if summary.grantedPermissions.isEmpty {
                    coordinator.finishImport()
                    finishAction()
                } else {
                    permissionsToAllow = summary.grantedPermissions
                }
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
            AppMigrationOverviewView(startAction: coordinator.startImport)
        } else {
            AppMigrationIntroView(continueAction: { showsOverview = true }, skipAction: skipAction)
        }
    }
}

#Preview {
    NavigationStack {
        AppMigrationFlowView(skipAction: {}, finishAction: {})
    }
}
