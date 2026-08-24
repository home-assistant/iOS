import Shared
import SwiftUI

/// Shown when the data is packaged but the new app is not installed yet. The payload is kept, so
/// coming back after installing continues where the user left off instead of starting over.
struct AppMigrationNeedsInstallView: View {
    let onOpenAppStore: () -> Void
    let onContinue: () -> Void

    var body: some View {
        BaseOnboardingView(
            illustration: { AppMigrationIllustration(symbol: .arrowDownAppFill) },
            title: L10n.AppMigration.Install.title,
            primaryDescription: L10n.AppMigration.Install.primaryDescription,
            secondaryDescription: L10n.AppMigration.Install.secondaryDescription,
            primaryActionTitle: L10n.AppMigration.Install.appStoreButton,
            primaryAction: onOpenAppStore,
            secondaryActionTitle: L10n.AppMigration.Install.continueButton,
            secondaryAction: onContinue
        )
    }
}

#Preview {
    AppMigrationNeedsInstallView(onOpenAppStore: {}, onContinue: {})
}
