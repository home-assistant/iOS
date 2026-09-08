import Shared
import SwiftUI

/// The previous app's only screen from the moment the new app asks for the setup.
struct AppMigrationExportContainerView: View {
    @ObservedObject private var coordinator = AppMigrationCoordinator.shared

    var body: some View {
        AppMigrationExportView(
            state: coordinator.exportState,
            summary: coordinator.exportSummary,
            transferAction: coordinator.transfer,
            openNewAppAction: coordinator.openNewApp,
            transferAgainAction: coordinator.transferAgain,
            cancelAction: coordinator.declineExport
        )
    }
}

#Preview {
    AppMigrationExportContainerView()
}
