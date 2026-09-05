import Shared
import SwiftUI

/// The end of an incoming migration: everything is in place, and the app being replaced has been
/// told to stand down.
struct AppMigrationImportCompletedView: View {
    let summary: AppMigrationImportSummary
    let onContinue: () -> Void

    var body: some View {
        BaseOnboardingView(
            illustration: { AppMigrationIllustration(symbol: .checkmarkCircleFill, tint: .green) },
            title: L10n.AppMigration.Import.Completed.title,
            primaryDescription: L10n.AppMigration.Import.Completed.primaryDescription(
                summary.serverCount,
                summary.configurationEntryCount
            ),
            secondaryDescription: summary.configurationFailed
                ? L10n.AppMigration.Import.Completed.configurationFailed
                : L10n.AppMigration.Import.Completed.secondaryDescription,
            primaryActionTitle: L10n.AppMigration.Import.Completed.continueButton,
            primaryAction: onContinue
        )
    }
}

#Preview {
    AppMigrationImportCompletedView(
        summary: .init(serverCount: 2, configurationEntryCount: 17, configurationFailed: false),
        onContinue: {}
    )
}
