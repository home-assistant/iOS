import Shared
import SwiftUI

/// The new app's side of the handoff: waiting for the previous app, then receiving and applying.
struct AppMigrationImportView: View {
    let state: AppMigrationImportState
    let openPreviousAppAction: () -> Void
    let retryAction: () -> Void
    let cancelAction: () -> Void

    var body: some View {
        switch state {
        case .waitingForPreviousApp:
            BaseOnboardingView(
                illustration: {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.haPrimary)
                        .frame(height: 96)
                },
                title: L10n.AppMigration.Import.Waiting.title,
                primaryDescription: L10n.AppMigration.Import.Waiting.body,
                primaryActionTitle: L10n.AppMigration.Import.Waiting.openButton,
                primaryAction: openPreviousAppAction,
                secondaryActionTitle: L10n.AppMigration.Import.cancelButton,
                secondaryAction: cancelAction
            )
        case .receiving, .applying:
            AppMigrationProgressView(script: .import)
        case let .failed(message):
            BaseOnboardingView(
                illustration: {
                    MaterialDesignIconsImage(icon: .alertCircleOutlineIcon, size: 96)
                        .foregroundStyle(.haErrorColor)
                },
                title: L10n.AppMigration.Import.Failed.title,
                primaryDescription: message,
                primaryActionTitle: L10n.AppMigration.Import.Failed.retryButton,
                primaryAction: retryAction,
                secondaryActionTitle: L10n.AppMigration.Import.Failed.manualButton,
                secondaryAction: cancelAction
            )
        }
    }
}

#Preview("Waiting") {
    AppMigrationImportView(
        state: .waitingForPreviousApp,
        openPreviousAppAction: {},
        retryAction: {},
        cancelAction: {}
    )
}

#Preview("Applying") {
    AppMigrationImportView(state: .applying, openPreviousAppAction: {}, retryAction: {}, cancelAction: {})
}

#Preview("Failed") {
    AppMigrationImportView(
        state: .failed(message: "The previous app sent an incomplete transfer."),
        openPreviousAppAction: {},
        retryAction: {},
        cancelAction: {}
    )
}
