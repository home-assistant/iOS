import Shared
import SwiftUI

/// The previous app's side of the handoff: confirm and package the setup, then stay as the only screen
/// until the user has checked the new app and deleted this one.
struct AppMigrationExportView: View {
    let state: AppMigrationExportState
    let summary: AppMigrationSummary
    let transferAction: () -> Void
    let openNewAppAction: () -> Void
    let transferAgainAction: () -> Void
    let cancelAction: () -> Void
    /// The erased screen draws its checkmark on; snapshots want it already drawn.
    var animatesErasedCheckmark = true

    var body: some View {
        switch state {
        case .preparing:
            AppMigrationProgressView(script: .export)
        case .idle:
            AppMigrationOverviewView(
                subtitle: L10n.AppMigration.Export.body,
                serversCaption: summary.serversDescription,
                actions: .transfer(state: .idle, transfer: transferAction, later: cancelAction)
            )
            .onAppear {
                AppMigrationHaptics.warning()
            }
        case let .failed(message):
            BaseOnboardingView(
                illustration: {
                    MaterialDesignIconsImage(icon: .alertCircleOutlineIcon, size: 96)
                        .foregroundStyle(.haErrorColor)
                        .padding(.top, DesignSystem.Spaces.two)
                },
                title: L10n.AppMigration.Export.Failed.title,
                primaryDescription: message,
                primaryActionTitle: L10n.AppMigration.Export.Failed.retryButton,
                primaryAction: {
                    AppMigrationHaptics.tap()
                    transferAction()
                },
                primaryActionIdentifier: AccessibilityIdentifier.migrationExportTransfer.rawValue,
                secondaryActionTitle: L10n.AppMigration.Export.laterButton,
                secondaryAction: {
                    AppMigrationHaptics.tap()
                    cancelAction()
                }
            )
            .onAppear {
                AppMigrationHaptics.error()
            }
        case .handedOff, .erased:
            afterHandoff
        }
    }

    private var afterHandoff: some View {
        BaseOnboardingView(
            illustration: {
                CheckmarkDrawOnView(
                    size: 96,
                    tint: .haSuccessColor,
                    animated: state == .erased && animatesErasedCheckmark
                )
                .padding(.top, DesignSystem.Spaces.two)
            },
            title: state == .erased
                ? L10n.AppMigration.Export.Erased.title
                : L10n.AppMigration.Export.HandedOff.title,
            primaryDescription: state == .erased
                ? L10n.AppMigration.Export.Erased.body
                : L10n.AppMigration.Export.HandedOff.verifyBody,
            primaryActionTitle: L10n.AppMigration.Export.HandedOff.openButton,
            primaryAction: openNewAppAction,
            primaryActionIdentifier: AccessibilityIdentifier.migrationExportOpenNewApp.rawValue,
            secondaryActionTitle: state == .erased ? nil : L10n.AppMigration.Export.HandedOff.transferAgainButton,
            secondaryAction: {},
            secondaryActionIdentifier: AccessibilityIdentifier.migrationExportTransferAgain.rawValue,
            secondaryActionConfirmation: BaseOnboardingConfirmation(
                title: L10n.AppMigration.Export.TransferAgainConfirmation.title,
                message: L10n.AppMigration.Export.TransferAgainConfirmation.resetBody,
                confirmTitle: L10n.AppMigration.Export.TransferAgainConfirmation.confirmButton,
                action: {
                    AppMigrationHaptics.warning()
                    transferAgainAction()
                }
            )
        )
        .onAppear {
            AppMigrationHaptics.success()
        }
    }
}

#Preview("Ready") {
    AppMigrationExportView(
        state: .idle,
        summary: .preview,
        transferAction: {},
        openNewAppAction: {},
        transferAgainAction: {},
        cancelAction: {}
    )
}

#Preview("Preparing") {
    AppMigrationExportView(
        state: .preparing,
        summary: .preview,
        transferAction: {},
        openNewAppAction: {},
        transferAgainAction: {},
        cancelAction: {}
    )
}

#Preview("Handed off") {
    AppMigrationExportView(
        state: .handedOff,
        summary: .preview,
        transferAction: {},
        openNewAppAction: {},
        transferAgainAction: {},
        cancelAction: {}
    )
}

#Preview("Erased") {
    AppMigrationExportView(
        state: .erased,
        summary: .preview,
        transferAction: {},
        openNewAppAction: {},
        transferAgainAction: {},
        cancelAction: {}
    )
}

#Preview("Failed") {
    AppMigrationExportView(
        state: .failed(message: "The new app is not installed on this device."),
        summary: .preview,
        transferAction: {},
        openNewAppAction: {},
        transferAgainAction: {},
        cancelAction: {}
    )
}
