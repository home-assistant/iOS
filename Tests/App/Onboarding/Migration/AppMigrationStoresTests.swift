import Foundation
@testable import HomeAssistant
import Shared
import Testing

/// The small pieces the transfer rests on: the session record, the pasteboard, the keychain stores,
/// the errors and the role.
struct AppMigrationStoresTests {
    @Test func theSessionStoreKeepsThePendingAndTheCompletedSession() {
        defer {
            AppMigrationSessionStore.clear()
            AppMigrationSessionStore.clearCompleted()
        }
        let session = AppMigrationSession.make()
        AppMigrationSessionStore.save(session)
        #expect(AppMigrationSessionStore.load() == session)
        AppMigrationSessionStore.clear()
        #expect(AppMigrationSessionStore.load() == nil)

        AppMigrationSessionStore.saveCompleted(session.id)
        #expect(AppMigrationSessionStore.loadCompleted() == session.id)
        AppMigrationSessionStore.clearCompleted()
        #expect(AppMigrationSessionStore.loadCompleted() == nil)
    }

    @Test func thePasteboardHandsThePayloadOverOnce() {
        let payload = Data("sealed".utf8)
        AppMigrationPasteboard.write(payload)
        #expect(AppMigrationPasteboard.take() == payload)
        #expect(AppMigrationPasteboard.take() == nil)
        AppMigrationPasteboard.write(payload)
        AppMigrationPasteboard.clear()
        #expect(AppMigrationPasteboard.take() == nil)
    }

    @Test func everyTransferredKeychainStoreNamesAService() {
        for store in AppMigrationKeychainStore.transferred {
            #expect(!store.service.isEmpty)
        }
        #expect(AppMigrationKeychainStore.unknown.service.isEmpty)
        #expect(AppMigrationKeychainStore.app.service == AppConstants.BundleID)
    }

    @Test func everyErrorExplainsItself() {
        for error in AppMigrationError.allCases {
            #expect(!error.localizedDescription.isEmpty)
        }
    }

    @Test func theRoleKnowsItsPeerAndSchemes() {
        defer { AppMigrationRole.override = nil }
        #expect(AppMigrationRole.newApp.peer == .previousApp)
        #expect(AppMigrationRole.previousApp.peer == .newApp)
        #expect(AppMigrationRole.newApp.urlScheme.hasPrefix("homeassistant-ohf"))
        #expect(AppMigrationRole.previousApp.urlScheme.hasPrefix("homeassistant-nc"))
        #expect(AppMigrationRole.previousApp.baseURL.host == AppMigrationLink.host)

        AppMigrationRole.override = .newApp
        #expect(AppMigrationRole.allowsOnboarding)
        AppMigrationRole.override = .previousApp
        #expect(AppMigrationRole.current == .previousApp)
        #expect(
            AppMigrationRole.allowsOnboarding == ProcessInfo.processInfo.arguments
                .contains("-AppMigrationAllowOnboarding")
        )
    }

    @Test func everyPermissionOpensASettingsDestination() {
        var destinations: Set<String> = []
        for permission in SensorPermission.allCases {
            destinations.insert(String(describing: permission.settingsDestination))
        }
        #expect(destinations.count == SensorPermission.allCases.count)
    }

    @Test func backgroundTaskIdentifiersComeFromTheBundle() {
        #expect(AppConstants.backgroundTaskIdentifier(suffix: "backgroundfetch").hasSuffix(".backgroundfetch"))
        #expect(AppConstants.backgroundTaskIdentifier(suffix: "nothing") == "\(AppConstants.BundleID).nothing")
    }

    @MainActor @Test func theLiveDependenciesAskIOSAboutTheOtherApp() async {
        let dependencies = AppMigrationCoordinatorDependencies()
        let nowhere = URL(string: "ha-migration-test-nowhere://migration")!
        #expect(!dependencies.canOpen(nowhere))
        let opened = await dependencies.open(nowhere)
        #expect(!opened)
        #expect(dependencies.pacing == AppMigrationProgressScript.totalDuration)
        dependencies.refreshLocalPushManagers()
    }

    @MainActor @Test func onlyPermissionsStillWorthAskingSurviveTheFilter() {
        let pending = AppMigrationFlowView.permissionsStillToAsk(from: [.notification, .location, .camera])
        #expect(pending.contains(.notification))
        #expect(Set(pending).isSubset(of: [.notification, .location, .camera]))
        #expect(AppMigrationFlowView.permissionsStillToAsk(from: []).isEmpty)
    }

    @Test func theDeclineReasonSurvivesItsLink() {
        let id = UUID()
        let url = AppMigrationLink.declined(sessionID: id, reason: .previousAppErased).url(to: .newApp)
        #expect(AppMigrationLink(url: url) == .declined(sessionID: id, reason: .previousAppErased))
    }
}
