import Shared
import SwiftUI

/// The new app's side of the handoff: checking the previous app opened, then receiving and applying.
struct AppMigrationImportView: View {
    let state: AppMigrationImportState
    let openPreviousAppAction: () -> Void
    let retryAction: () -> Void
    let cancelAction: () -> Void

    @State private var showsManualConfirmation = false

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
                secondaryAction: { showsManualConfirmation = true },
                secondaryActionIdentifier: AccessibilityIdentifier.migrationImportManual.rawValue
            )
            .alert(
                L10n.AppMigration.Import.Failed.ManualConfirmation.title,
                isPresented: $showsManualConfirmation
            ) {
                Button(L10n.AppMigration.Import.Failed.ManualConfirmation.confirmButton, role: .destructive) {
                    cancelAction()
                }
                .accessibilityIdentifier(AccessibilityIdentifier.migrationImportManualConfirm.rawValue)
                Button(L10n.cancelLabel, role: .cancel) {}
            } message: {
                Text(L10n.AppMigration.Import.Failed.ManualConfirmation.body)
            }
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
