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
            VStack(spacing: DesignSystem.Spaces.three) {
                Spacer()
                ProgressView()
                    .controlSize(.large)
                    .tint(.haPrimary)
                Text(
                    state == .receiving
                        ? L10n.AppMigration.Import.Receiving.title
                        : L10n.AppMigration.Import.Applying.title
                )
                .font(DesignSystem.Font.title2.bold())
                .multilineTextAlignment(.center)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(DesignSystem.Spaces.two)
            .background(Color(uiColor: .systemBackground))
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
