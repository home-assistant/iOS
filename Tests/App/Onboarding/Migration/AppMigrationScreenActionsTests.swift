@testable import HomeAssistant
import Shared
import SwiftUI
import Testing
import UIKit

/// What the transfer screens' buttons do, driven directly against coordinators that stand in for
/// either app.
@MainActor
struct AppMigrationScreenActionsTests {
    private static func coordinator(role: AppMigrationRole, canOpen: Bool, opened: @escaping (URL) -> Void = { _ in
    }) -> AppMigrationCoordinator {
        var dependencies = AppMigrationCoordinatorDependencies()
        dependencies.role = role
        dependencies.canOpen = { _ in canOpen }
        dependencies.open = { url in
            opened(url)
            return true
        }
        dependencies.pacing = 0
        dependencies.adoptPushRegistration = {}
        dependencies.releasePushRegistration = {}
        dependencies.refreshLocalPushManagers = {}
        return AppMigrationCoordinator(dependencies: dependencies)
    }

    @Test func theCompleteScreenErasesFirstAndContinuesOnceTheNextStepsShow() {
        var erased = 0
        var continued = 0
        let beforeNextSteps = AppMigrationCompleteView(
            summary: .preview,
            eraseAction: { erased += 1 },
            continueAction: { continued += 1 }
        )
        beforeNextSteps.primaryTapped()
        #expect(erased == 1)
        beforeNextSteps.secondaryTapped()
        #expect(continued == 0)

        let withNextSteps = AppMigrationCompleteView(
            summary: .preview,
            previousAppErased: true,
            eraseAction: { erased += 1 },
            continueAction: { continued += 1 }
        )
        withNextSteps.primaryTapped()
        #expect(continued == 1)
        withNextSteps.secondaryTapped()
        #expect(erased == 2)

        let withoutPreviousApp = AppMigrationCompleteView(summary: .preview, continueAction: { continued += 1 })
        withoutPreviousApp.primaryTapped()
        withoutPreviousApp.secondaryTapped()
        #expect(continued == 2)
    }

    @Test func theAnnouncementStartsTheTransferOrSendsToTheStore() {
        AppMigrationHandoffStore.save(nil)
        defer { AppMigrationHandoffStore.save(nil) }
        let notInstalled = Self.coordinator(role: .previousApp, canOpen: false)
        AppMigrationAnnouncementView(coordinator: notInstalled, onViewed: {}).startTransfer()
        #expect(notInstalled.exportRequest == nil)

        let installed = Self.coordinator(role: .previousApp, canOpen: true)
        let announcement = AppMigrationAnnouncementView(coordinator: installed, onViewed: {})
        announcement.startTransfer()
        #expect(installed.exportRequest != nil)
        announcement.postpone()
        installed.declineExport()
    }

    @Test func theStoreStepRetriesTheTransferAfterTheUserInstalledTheApp() {
        AppMigrationHandoffStore.save(nil)
        defer { AppMigrationHandoffStore.save(nil) }
        var started = 0
        let notInstalled = Self.coordinator(role: .previousApp, canOpen: false)
        AppMigrationGetNewAppView(coordinator: notInstalled, backAction: {}, transferStartedAction: { started += 1 })
            .startTransferIfInstalled(reportMissing: true)
        #expect(started == 0)

        let installed = Self.coordinator(role: .previousApp, canOpen: true)
        AppMigrationGetNewAppView(coordinator: installed, backAction: {}, transferStartedAction: { started += 1 })
            .startTransferIfInstalled(reportMissing: false)
        #expect(started == 1)
        installed.declineExport()
    }

    @Test func theEmptyPreviousAppOpensTheNewAppWhenItIsThere() async {
        var opened: [URL] = []
        let installed = Self.coordinator(role: .previousApp, canOpen: true) { opened.append($0) }
        AppMigrationNoServersView(coordinator: installed).primaryTapped()
        let clock = ContinuousClock()
        let start = clock.now
        while opened.isEmpty, clock.now - start < .seconds(5) {
            try? await Task.sleep(for: .milliseconds(20))
        }
        #expect(opened.first == AppMigrationRole.newApp.baseURL)

        AppMigrationNoServersView(coordinator: Self.coordinator(role: .previousApp, canOpen: false)).primaryTapped()
        #expect(opened.count == 1)
    }

    @Test func leavingTheSuccessScreenAsksForPermissionsOnlyWhenSomeAreLeft() {
        var finished = 0
        let coordinator = Self.coordinator(role: .newApp, canOpen: true)
        let flow = AppMigrationFlowView(coordinator: coordinator, skipAction: {}, finishAction: { finished += 1 })
        flow.finishAfterSuccess(AppMigrationSummary(serverNames: ["Home"]))
        #expect(finished == 1)
        flow.finishAfterSuccess(AppMigrationSummary(serverNames: ["Home"], grantedPermissions: [.notification]))
        #expect(finished == 1)
        AppMigrationHaptics.tap()
    }

    @Test func theImporterRejectsWhatItCannotApply() throws {
        let unsupported = AppMigrationPayload(
            version: AppMigrationPayload.currentVersion + 1,
            sessionID: UUID(),
            serverNames: [],
            database: Data(),
            appGroupDefaults: Data(),
            keychainItems: [],
            grantedPermissions: nil,
            clientCertificates: nil
        )
        #expect(throws: AppMigrationError.unsupportedVersion) {
            try AppMigrationImporter().apply(unsupported)
        }

        let exported = try AppMigrationExporter().makePayload(sessionID: UUID(), grantedPermissions: [])
        let unreadableDefaults = AppMigrationPayload(
            version: exported.version,
            sessionID: exported.sessionID,
            serverNames: exported.serverNames,
            database: exported.database,
            appGroupDefaults: Data("not a property list".utf8),
            keychainItems: [],
            grantedPermissions: nil,
            clientCertificates: nil
        )
        #expect(throws: (any Error).self) {
            try AppMigrationImporter().apply(unreadableDefaults)
        }
    }

    @Test func settingsOffersTheTransferToThePreviousApp() {
        AppMigrationRole.override = .previousApp
        AppMigrationHandoffStore.save(nil)
        defer { AppMigrationRole.override = nil }
        #expect(AppMigrationAnnouncement.isRelevant)
        _ = SettingsView().body
        AppMigrationRole.override = .newApp
        #expect(!AppMigrationAnnouncement.isRelevant)
    }

    @Test func theCheckmarkDrawsItselfOnWhenShown() async throws {
        let controller = UIHostingController(rootView: CheckmarkDrawOnView())
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(300))
        window.isHidden = true
    }
}
