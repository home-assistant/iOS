import Shared
import SwiftUI

/// Presented in the previous app when the new app asks for the setup.
struct AppMigrationExportContainerView: View {
    @ObservedObject private var coordinator = AppMigrationCoordinator.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        AppMigrationExportView(
            state: coordinator.exportState,
            summary: coordinator.exportSummary,
            transferAction: coordinator.transfer,
            openNewAppAction: coordinator.openNewApp,
            cancelAction: {
                coordinator.declineExport()
                dismiss()
            }
        )
        .interactiveDismissDisabled(coordinator.exportState == .preparing)
    }
}

#Preview {
    AppMigrationExportContainerView()
}
