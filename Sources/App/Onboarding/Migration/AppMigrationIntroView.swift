import Shared
import SwiftUI

/// First screen of the transfer in the new app: why it exists and that nothing leaves the device.
struct AppMigrationIntroView: View {
    let continueAction: () -> Void
    let skipAction: () -> Void

    var body: some View {
        BaseOnboardingView(
            illustration: {
                MaterialDesignIconsImage(icon: .transferIcon, size: 96)
                    .foregroundStyle(.haPrimary)
            },
            title: L10n.AppMigration.Intro.title,
            primaryDescription: L10n.AppMigration.Intro.body,
            primaryActionTitle: L10n.AppMigration.Intro.continueButton,
            primaryAction: continueAction,
            primaryActionIdentifier: AccessibilityIdentifier.migrationIntroContinue.rawValue,
            secondaryActionTitle: L10n.AppMigration.Intro.skipButton,
            secondaryAction: skipAction
        )
    }
}

#Preview {
    AppMigrationIntroView(continueAction: {}, skipAction: {})
}
