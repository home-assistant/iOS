import Shared
import SwiftUI

/// An incoming migration that could not be applied. There is nothing to retry here — the payload
/// lives in the app that sent it — so this points the user back there.
struct AppMigrationImportFailureView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        BaseOnboardingView(
            illustration: { AppMigrationIllustration(symbol: .exclamationmarkTriangleFill, tint: .red) },
            title: L10n.AppMigration.Import.Failure.title,
            primaryDescription: message,
            secondaryDescription: L10n.AppMigration.Import.Failure.secondaryDescription,
            primaryActionTitle: L10n.AppMigration.Import.Failure.dismissButton,
            primaryAction: onDismiss
        )
    }
}

#Preview {
    AppMigrationImportFailureView(message: "This link was written by a newer app.", onDismiss: {})
}
