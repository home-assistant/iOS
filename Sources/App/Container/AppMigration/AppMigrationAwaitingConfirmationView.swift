import Shared
import SwiftUI

/// Shown after the new app has been opened with the payload. This app stays put until the new app
/// reports back, so a user who bounced back too early can send the handoff again.
struct AppMigrationAwaitingConfirmationView: View {
    let onOpenAgain: () -> Void
    let onLater: () -> Void

    var body: some View {
        BaseOnboardingView(
            illustration: { AppMigrationIllustration(symbol: .arrowRightCircleFill) },
            title: L10n.AppMigration.Awaiting.title,
            primaryDescription: L10n.AppMigration.Awaiting.primaryDescription,
            secondaryDescription: L10n.AppMigration.Awaiting.secondaryDescription,
            primaryActionTitle: L10n.AppMigration.Awaiting.openAgainButton,
            primaryAction: onOpenAgain,
            secondaryActionTitle: L10n.AppMigration.Awaiting.laterButton,
            secondaryAction: onLater
        )
    }
}

#Preview {
    AppMigrationAwaitingConfirmationView(onOpenAgain: {}, onLater: {})
}
