import SFSafeSymbols
import Shared
import SwiftUI

/// Shown when the transfer is asked for but the new app is not installed: send the user to the App
/// Store, then pick the transfer up as soon as the new app is found on the device.
struct AppMigrationGetNewAppView: View {
    @ObservedObject private var coordinator = AppMigrationCoordinator.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var notFoundYet = false
    let backAction: () -> Void
    let transferStartedAction: () -> Void

    var body: some View {
        BaseOnboardingView(
            illustration: {
                MaterialDesignIconsImage(icon: .downloadCircleOutlineIcon, size: 96)
                    .foregroundStyle(.haPrimary)
                    .padding(.top, DesignSystem.Spaces.two)
            },
            title: L10n.AppMigration.GetNewApp.title,
            primaryDescription: L10n.AppMigration.GetNewApp.body,
            content: {
                if notFoundYet {
                    HAAlertView(title: L10n.AppMigration.GetNewApp.NotFound.title, alertType: .warning) {
                        Text(L10n.AppMigration.GetNewApp.NotFound.body)
                    } action: {
                        EmptyView()
                    }
                    .padding(.top, DesignSystem.Spaces.two)
                }
            },
            primaryActionTitle: L10n.AppMigration.GetNewApp.storeButton,
            primaryAction: {
                AppMigrationHaptics.tap()
                URLOpener.shared.open(AppMigrationAnnouncement.newAppStoreURL, options: [:], completionHandler: nil)
            },
            primaryActionIdentifier: AccessibilityIdentifier.migrationGetNewAppStore.rawValue,
            secondaryActionTitle: L10n.AppMigration.GetNewApp.installedButton,
            secondaryAction: {
                AppMigrationHaptics.tap()
                startTransferIfInstalled(reportMissing: true)
            },
            secondaryActionIdentifier: AccessibilityIdentifier.migrationGetNewAppInstalled.rawValue
        )
        .overlay(alignment: .topLeading) {
            Button(action: backAction) {
                Image(systemSymbol: .chevronLeft)
                    .font(DesignSystem.Font.body.weight(.semibold))
                    .padding(DesignSystem.Spaces.one)
            }
            .tint(.haPrimary)
            .padding(DesignSystem.Spaces.one)
            .accessibilityLabel(L10n.AppMigration.GetNewApp.backButton)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                startTransferIfInstalled(reportMissing: false)
            }
        }
    }

    private func startTransferIfInstalled(reportMissing: Bool) {
        if coordinator.beginTransferFromThisApp() {
            transferStartedAction()
        } else if reportMissing {
            AppMigrationHaptics.warning()
            withAnimation(DesignSystem.Animation.default) {
                notFoundYet = true
            }
        }
    }
}

#Preview {
    AppMigrationGetNewAppView(backAction: {}, transferStartedAction: {})
}
