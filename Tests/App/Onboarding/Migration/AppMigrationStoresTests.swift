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

    @Test func theDeclineReasonSurvivesItsLink() {
        let id = UUID()
        let url = AppMigrationLink.declined(sessionID: id, reason: .previousAppErased).url(to: .newApp)
        #expect(AppMigrationLink(url: url) == .declined(sessionID: id, reason: .previousAppErased))
    }
}
