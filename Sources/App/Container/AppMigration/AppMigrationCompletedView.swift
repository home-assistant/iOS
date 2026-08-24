import Shared
import SwiftUI

/// The end of the migration on the app being replaced: the new app confirmed the import, so this one
/// has stopped sending anything to Home Assistant and only asks to be deleted.
struct AppMigrationCompletedView: View {
    let serverCount: Int
    let onDone: () -> Void

    var body: some View {
        BaseOnboardingView(
            illustration: { AppMigrationIllustration(symbol: .checkmarkCircleFill) },
            title: L10n.AppMigration.Completed.title,
            primaryDescription: L10n.AppMigration.Completed.primaryDescription(serverCount),
            secondaryDescription: L10n.AppMigration.Completed.secondaryDescription,
            primaryActionTitle: L10n.AppMigration.Completed.doneButton,
            primaryAction: onDone
        )
    }
}

#Preview {
    AppMigrationCompletedView(serverCount: 2, onDone: {})
}
