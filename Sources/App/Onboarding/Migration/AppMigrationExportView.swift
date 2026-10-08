import SFSafeSymbols
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

    @State private var showsTransferAgainConfirmation = false

    var body: some View {
        switch state {
        case .preparing:
            AppMigrationProgressView(script: .export)
        case .idle, .failed:
            AppMigrationOverviewView(
                subtitle: L10n.AppMigration.Export.body,
                serversCaption: summary.serversDescription,
                failure: failureMessage,
                actions: .transfer(state: progressButtonState, transfer: transferAction, later: cancelAction)
            )
            .onAppear {
                if state == .idle {
                    AppMigrationHaptics.warning()
                } else {
                    AppMigrationHaptics.error()
                }
            }
        case .handedOff, .erased:
            afterHandoff
        }
    }

    private var afterHandoff: some View {
        BaseOnboardingView(
            illustration: {
                MaterialDesignIconsImage(icon: .checkCircleOutlineIcon, size: 96)
                    .foregroundStyle(.haSuccessColor)
                    .padding(.top, DesignSystem.Spaces.two)
            },
            title: state == .erased ? L10n.AppMigration.Export.Erased.title : L10n.AppMigration.Export.HandedOff.title,
            primaryDescription: state == .erased
                ? L10n.AppMigration.Export.Erased.body
                : L10n.AppMigration.Export.HandedOff.verifyBody,
            primaryActionTitle: L10n.AppMigration.Export.HandedOff.openButton,
            primaryAction: openNewAppAction,
            primaryActionIdentifier: AccessibilityIdentifier.migrationExportOpenNewApp.rawValue,
            secondaryActionTitle: state == .erased ? nil : L10n.AppMigration.Export.HandedOff.transferAgainButton,
            secondaryAction: {
                AppMigrationHaptics.tap()
                showsTransferAgainConfirmation = true
            },
            secondaryActionIdentifier: AccessibilityIdentifier.migrationExportTransferAgain.rawValue
        )
        .confirmationDialog(
            L10n.AppMigration.Export.TransferAgainConfirmation.title,
            isPresented: $showsTransferAgainConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.AppMigration.Export.TransferAgainConfirmation.confirmButton) {
                AppMigrationHaptics.warning()
                transferAgainAction()
            }
        } message: {
            Text(L10n.AppMigration.Export.TransferAgainConfirmation.resetBody)
        }
        .onAppear {
            AppMigrationHaptics.success()
        }
    }

    private var failureMessage: String? {
        if case let .failed(message) = state {
            return message
        }
        return nil
    }

    private var progressButtonState: HAProgressButtonState {
        switch state {
        case .idle, .handedOff, .erased: .idle
        case .preparing: .inProgress
        case .failed: .failure
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
