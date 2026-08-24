import Shared
import SwiftUI

/// Packaging or handing over failed. The only way forward is to try again: the data never leaves the
/// device except into the new app, so there is nothing to fall back to that would not mean asking the
/// user to shepherd their own credentials through a file.
struct AppMigrationFailureView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        BaseOnboardingView(
            illustration: { AppMigrationIllustration(symbol: .exclamationmarkTriangleFill, tint: .red) },
            title: L10n.AppMigration.Failure.title,
            primaryDescription: message,
            secondaryDescription: L10n.AppMigration.Failure.secondaryDescription,
            primaryActionTitle: L10n.AppMigration.Failure.retryButton,
            primaryAction: onRetry
        )
    }
}

#Preview {
    AppMigrationFailureView(
        message: "The new app could not be reached.",
        onRetry: {}
    )
}
