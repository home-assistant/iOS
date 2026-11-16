import Shared
import SwiftUI

/// The new app's side of the handoff: checking the previous app opened, then receiving and applying.
struct AppMigrationImportView: View {
    let state: AppMigrationImportState
    let openPreviousAppAction: () -> Void
    let retryAction: () -> Void
    let replaceAction: () -> Void
    let keepAction: () -> Void
    let cancelAction: () -> Void

    /// Server names as a sentence, or a placeholder when a side has none.
    static func serversDescription(_ names: [String]) -> String {
        names.isEmpty ? L10n.AppMigration.Import.Replace.noServers : ListFormatter.localizedString(byJoining: names)
    }

    var body: some View {
        switch state {
        case .openingPreviousApp:
            BaseOnboardingView(
                illustration: {
                    MaterialDesignIconsImage(icon: .transferIcon, size: 96)
                        .foregroundStyle(.haPrimary)
                        .padding(.top, DesignSystem.Spaces.two)
                },
                title: L10n.AppMigration.Import.OpenCheck.title,
                primaryDescription: L10n.AppMigration.Import.OpenCheck.body,
                primaryActionTitle: L10n.AppMigration.Import.OpenCheck.retryButton,
                primaryAction: {
                    AppMigrationHaptics.tap()
                    openPreviousAppAction()
                },
                secondaryActionTitle: L10n.AppMigration.Import.cancelButton,
                secondaryAction: cancelAction
            )
        case .receiving, .applying:
            AppMigrationProgressView(script: .import)
        case let .confirmingReplacement(existingServerNames, incomingServerNames):
            BaseOnboardingView(
                illustration: {
                    MaterialDesignIconsImage(icon: .databaseAlertOutlineIcon, size: 96)
                        .foregroundStyle(.haErrorColor)
                        .padding(.top, DesignSystem.Spaces.two)
                },
                title: L10n.AppMigration.Import.Replace.title,
                primaryDescription: L10n.AppMigration.Import.Replace.body(Self.serversDescription(existingServerNames)),
                secondaryDescription: L10n.AppMigration.Import.Replace
                    .incoming(Self.serversDescription(incomingServerNames)),
                primaryActionTitle: L10n.AppMigration.Import.Replace.replaceButton,
                primaryAction: {
                    AppMigrationHaptics.warning()
                    replaceAction()
                },
                primaryActionIdentifier: AccessibilityIdentifier.migrationImportReplace.rawValue,
                secondaryActionTitle: L10n.AppMigration.Import.Replace.keepButton,
                secondaryAction: {
                    AppMigrationHaptics.tap()
                    keepAction()
                },
                secondaryActionIdentifier: AccessibilityIdentifier.migrationImportKeep.rawValue
            )
        case let .failed(message):
            BaseOnboardingView(
                illustration: {
                    MaterialDesignIconsImage(icon: .alertCircleOutlineIcon, size: 96)
                        .foregroundStyle(.haErrorColor)
                        .padding(.top, DesignSystem.Spaces.two)
                },
                title: L10n.AppMigration.Import.Failed.title,
                primaryDescription: message,
                primaryActionTitle: L10n.AppMigration.Import.Failed.retryButton,
                primaryAction: retryAction,
                primaryActionIdentifier: AccessibilityIdentifier.migrationImportRetry.rawValue,
                secondaryActionTitle: L10n.AppMigration.Import.Failed.manualButton,
                secondaryAction: cancelAction,
                secondaryActionIdentifier: AccessibilityIdentifier.migrationImportManual.rawValue,
                secondaryActionConfirmation: BaseOnboardingConfirmation(
                    title: L10n.AppMigration.Import.Failed.ManualConfirmation.title,
                    message: L10n.AppMigration.Import.Failed.ManualConfirmation.body,
                    confirmTitle: L10n.AppMigration.Import.Failed.ManualConfirmation.confirmButton,
                    confirmRole: .destructive,
                    confirmIdentifier: AccessibilityIdentifier.migrationImportManualConfirm.rawValue,
                    action: cancelAction
                )
            )
            .onAppear {
                AppMigrationHaptics.error()
            }
        }
    }
}

#Preview("Opening the previous app") {
    AppMigrationImportView(
        state: .openingPreviousApp,
        openPreviousAppAction: {},
        retryAction: {},
        replaceAction: {},
        keepAction: {},
        cancelAction: {}
    )
}

#Preview("Applying") {
    AppMigrationImportView(
        state: .applying,
        openPreviousAppAction: {},
        retryAction: {},
        replaceAction: {},
        keepAction: {},
        cancelAction: {}
    )
}

#Preview("Replace an existing setup") {
    AppMigrationImportView(
        state: .confirmingReplacement(existingServerNames: ["Home"], incomingServerNames: ["Home", "Cabin"]),
        openPreviousAppAction: {},
        retryAction: {},
        replaceAction: {},
        keepAction: {},
        cancelAction: {}
    )
}

#Preview("Failed") {
    AppMigrationImportView(
        state: .failed(message: "The previous app sent an incomplete transfer."),
        openPreviousAppAction: {},
        retryAction: {},
        replaceAction: {},
        keepAction: {},
        cancelAction: {}
    )
}
