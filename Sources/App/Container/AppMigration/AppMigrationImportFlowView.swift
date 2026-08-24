import Shared
import SwiftUI

/// The whole incoming migration on the app taking over. Presented full screen over whatever the app
/// was showing — including onboarding, which is exactly what a fresh install is showing when the
/// handoff arrives.
struct AppMigrationImportFlowView: View {
    @StateObject private var viewModel: AppMigrationImportViewModel
    let onDismiss: () -> Void

    init(chunk: AppMigrationChunk, onDismiss: @escaping () -> Void) {
        self._viewModel = StateObject(wrappedValue: AppMigrationImportViewModel(chunk: chunk))
        self.onDismiss = onDismiss
    }

    var body: some View {
        content
            .animation(.easeInOut(duration: 0.3), value: viewModel.phase)
            .interactiveDismissDisabled()
            .appMigrationKeepsScreenAwake()
            .task { await viewModel.run() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .running:
            AppMigrationProgressView<AppMigrationImportStep>(
                symbol: .trayAndArrowDownFill,
                title: L10n.AppMigration.Import.Progress.title,
                subtitle: L10n.AppMigration.Import.Progress.subtitle,
                state: { viewModel.state(for: $0) },
                transfer: viewModel.transfer,
                transferCaption: viewModel.transfer.map {
                    L10n.AppMigration.Transfer.caption($0.completed + 1, $0.total)
                } ?? ""
            )
        case let .completed(summary):
            AppMigrationImportCompletedView(summary: summary, onContinue: onDismiss)
        case let .failed(message):
            AppMigrationImportFailureView(message: message, onDismiss: onDismiss)
        }
    }
}

#Preview {
    AppMigrationImportFlowView(
        chunk: .init(sessionID: "preview", index: 0, total: 1, data: ""),
        onDismiss: {}
    )
}
