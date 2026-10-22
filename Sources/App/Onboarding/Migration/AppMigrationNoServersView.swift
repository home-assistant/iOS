import Shared
import StoreKit
import SwiftUI

/// The previous app with nothing set up: it no longer connects to a Home Assistant server, so instead
/// of onboarding it points at the new app, opening it when it is installed and the App Store otherwise.
struct AppMigrationNoServersView: View {
    @ObservedObject var coordinator: AppMigrationCoordinator = .shared
    @State private var isStoreOverlayPresented = false

    var body: some View {
        BaseOnboardingView(
            illustration: {
                MaterialDesignIconsImage(icon: .cellphoneArrowDownIcon, size: 96)
                    .foregroundStyle(.haPrimary)
                    .padding(.top, DesignSystem.Spaces.two)
            },
            title: L10n.AppMigration.NoServers.movedTitle,
            primaryDescription: L10n.AppMigration.NoServers.movedBody,
            primaryActionTitle: coordinator.isNewAppInstalled
                ? L10n.AppMigration.Export.HandedOff.openButton
                : L10n.AppMigration.GetNewApp.storeButton,
            primaryAction: primaryTapped,
            primaryActionIdentifier: AccessibilityIdentifier.migrationNoServersPrimary.rawValue
        )
        .appStoreOverlay(isPresented: $isStoreOverlayPresented) {
            SKOverlay.AppConfiguration(appIdentifier: AppMigrationAnnouncement.newAppStoreID, position: .bottom)
        }
    }

    func primaryTapped() {
        AppMigrationHaptics.tap()
        if coordinator.isNewAppInstalled {
            coordinator.openNewApp()
        } else {
            #if targetEnvironment(macCatalyst)
            URLOpener.shared.open(AppMigrationAnnouncement.newAppStoreURL, options: [:], completionHandler: nil)
            #else
            isStoreOverlayPresented = true
            #endif
        }
    }
}

#Preview {
    AppMigrationNoServersView()
}
