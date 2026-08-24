import Shared
import SwiftUI

/// The whole migration on the app being replaced, from the explanation through to the confirmation
/// that it has been retired. Presented full screen: it is not something to leave half done.
struct AppMigrationFlowView: View {
    @StateObject private var viewModel = AppMigrationViewModel()
    let onDismiss: () -> Void

    var body: some View {
        content
            .animation(.easeInOut(duration: 0.3), value: viewModel.phase)
            .interactiveDismissDisabled()
            .appMigrationKeepsScreenAwake()
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .intro:
            AppMigrationIntroView(
                serverCount: viewModel.serverCount,
                onStart: { Task { await viewModel.start() } },
                onLater: {
                    viewModel.snoozePrompt()
                    onDismiss()
                }
            )
        case .packaging:
            AppMigrationProgressView<AppMigrationExportStep>(
                symbol: .trayAndArrowUpFill,
                title: L10n.AppMigration.Progress.title,
                subtitle: L10n.AppMigration.Progress.subtitle,
                state: { viewModel.state(for: $0) },
                transfer: viewModel.transfer,
                transferCaption: viewModel.transfer.map {
                    L10n.AppMigration.Transfer.caption($0.completed + 1, $0.total)
                } ?? ""
            )
        case .needsDestinationApp:
            AppMigrationNeedsInstallView(
                onOpenAppStore: { viewModel.openAppStore() },
                onContinue: { viewModel.openDestinationAgain() }
            )
        case .awaitingConfirmation:
            AppMigrationAwaitingConfirmationView(
                onOpenAgain: { viewModel.openDestinationAgain() },
                onLater: onDismiss
            )
        case let .completed(serverCount):
            AppMigrationCompletedView(serverCount: serverCount, onDone: onDismiss)
        case let .failed(message):
            AppMigrationFailureView(
                message: message,
                onRetry: { Task { await viewModel.start() } }
            )
        }
    }
}

#Preview {
    AppMigrationFlowView(onDismiss: {})
}
