import Shared
import SwiftUI

/// Packaging or handing over failed.
///
/// Two ways out, and neither involves the user shepherding their own credentials through a file:
/// try again, or put it off. "Later" matters more than it looks — this app still holds every server,
/// so the user can go on using Home Assistant while the move waits.
struct AppMigrationFailureView: View {
    let message: String
    let onRetry: () -> Void
    let onLater: () -> Void

    var body: some View {
        BaseOnboardingView(
            illustration: { AppMigrationIllustration(symbol: .exclamationmarkTriangleFill, tint: .red) },
            title: L10n.AppMigration.Failure.title,
            primaryDescription: message,
            secondaryDescription: L10n.AppMigration.Failure.secondaryDescription,
            primaryActionTitle: L10n.AppMigration.Failure.retryButton,
            primaryAction: onRetry,
            secondaryActionTitle: L10n.AppMigration.Failure.laterButton,
            secondaryAction: onLater
        )
        .overlay(alignment: .topLeading) {
            AppMigrationSettingsShortcutButton()
                .padding(.leading, DesignSystem.Spaces.one)
        }
    }
}

#Preview {
    AppMigrationFailureView(
        message: "The new app could not be reached.",
        onRetry: {},
        onLater: {}
    )
}
