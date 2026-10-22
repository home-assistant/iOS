@testable import HomeAssistant
import Shared
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

/// Every screen of the transfer, on both sides of the handoff, in every state it can land in.
struct AppMigrationScreensTests {
    private static let failure = "Your existing app sent an incomplete transfer."

    // MARK: - New app

    @MainActor @Test func welcomeWithTransfer() {
        assertLightDarkSnapshots(
            of: OnboardingWelcomeView(continueAction: {}, transferAction: {}),
            named: "new-01-welcome"
        )
    }

    @MainActor @Test func intro() {
        assertLightDarkSnapshots(of: AppMigrationIntroView(continueAction: {}, skipAction: {}), named: "new-02-intro")
    }

    @MainActor @Test func overview() {
        assertLightDarkSnapshots(of: AppMigrationOverviewView(startAction: {}), named: "new-03-overview")
    }

    @MainActor @Test func openingPreviousApp() {
        assertLightDarkSnapshots(of: importView(.openingPreviousApp), named: "new-04-open-check")
    }

    @MainActor @Test func importProgress() {
        assertLightDarkSnapshots(of: importView(.applying), named: "new-05-progress")
    }

    @MainActor @Test func importFailed() {
        assertLightDarkSnapshots(of: importView(.failed(message: Self.failure)), named: "new-06-failed")
    }

    @MainActor @Test func complete() {
        assertLightDarkSnapshots(
            of: AppMigrationCompleteView(summary: .preview, eraseAction: {}, continueAction: {}),
            named: "new-07-complete"
        )
    }

    @MainActor @Test func completeWithPreviousAppErased() {
        assertLightDarkSnapshots(
            of: AppMigrationCompleteView(
                summary: .preview,
                previousAppErased: true,
                eraseAction: {},
                continueAction: {}
            ),
            named: "new-07c-complete-erased"
        )
    }

    @MainActor @Test func completeWithoutServers() {
        assertLightDarkSnapshots(
            of: AppMigrationCompleteView(summary: AppMigrationSummary(serverNames: []), continueAction: {}),
            named: "new-07b-complete-no-servers"
        )
    }

    @MainActor @Test func permissions() {
        let previousStatus = Current.location.permissionStatus
        defer { Current.location.permissionStatus = previousStatus }
        Current.location.permissionStatus = { .notDetermined }
        assertLightDarkSnapshots(
            of: AppMigrationPermissionsView(permissions: [.location, .notification], continueAction: {}),
            named: "new-08-permissions"
        )
    }

    // MARK: - Previous app

    @MainActor @Test func announcement() {
        assertLightDarkSnapshots(of: AppMigrationAnnouncementView(onViewed: {}), named: "old-00-announcement")
    }

    @MainActor @Test func announcementSlidesToTheStoreStep() {
        assertLightDarkSnapshots(
            of: AppMigrationAnnouncementView(showsGetNewApp: true, onViewed: {}),
            named: "old-00a-announcement-store"
        )
    }

    @MainActor @Test func getNewAppReportsItIsNotInstalledYet() {
        assertLightDarkSnapshots(
            of: AppMigrationGetNewAppView(notFoundYet: true, backAction: {}, transferStartedAction: {}),
            named: "old-00b2-get-new-app-not-found"
        )
    }

    @MainActor @Test func getNewApp() {
        assertLightDarkSnapshots(
            of: AppMigrationGetNewAppView(backAction: {}, transferStartedAction: {}),
            named: "old-00b-get-new-app"
        )
    }

    @MainActor @Test func noServers() {
        assertLightDarkSnapshots(of: AppMigrationNoServersView(), named: "old-00c-no-servers")
    }

    @MainActor @Test func exportRequested() {
        assertLightDarkSnapshots(of: exportView(.idle), named: "old-01-request")
    }

    @MainActor @Test func exportProgress() {
        assertLightDarkSnapshots(of: exportView(.preparing), named: "old-02-progress")
    }

    @MainActor @Test func exportHandedOff() {
        assertLightDarkSnapshots(of: exportView(.handedOff), named: "old-03-handed-off")
    }

    @MainActor @Test func exportErased() {
        assertLightDarkSnapshots(of: exportView(.erased), named: "old-05-erased")
    }

    @MainActor @Test func exportFailed() {
        assertLightDarkSnapshots(
            of: exportView(.failed(message: "The Open Home Foundation app is not installed on this device.")),
            named: "old-04-failed"
        )
    }

    // MARK: - Containers

    @MainActor @Test func flowStartsWithTheIntroAndThenAsksThePreviousApp() async {
        var dependencies = AppMigrationCoordinatorDependencies()
        dependencies.role = .newApp
        dependencies.open = { _ in true }
        dependencies.canOpen = { _ in true }
        let coordinator = AppMigrationCoordinator(dependencies: dependencies)
        defer {
            coordinator.cancelImport()
            AppMigrationSessionStore.clear()
        }
        assertLightDarkSnapshots(
            of: AppMigrationFlowView(coordinator: coordinator, skipAction: {}, finishAction: {}),
            named: "new-00-flow-intro"
        )
        coordinator.startImport()
        assertLightDarkSnapshots(
            of: AppMigrationFlowView(coordinator: coordinator, skipAction: {}, finishAction: {}),
            named: "new-00b-flow-open-check"
        )
    }

    @MainActor @Test func flowShowsThePermissionsItStillHasToAsk() {
        assertLightDarkSnapshots(
            of: AppMigrationFlowView(permissionsToAllow: [.location, .notification], skipAction: {}, finishAction: {}),
            named: "new-00d-flow-permissions"
        )
    }

    @MainActor @Test func exportContainerShowsTheRequestThePreviousAppReceived() {
        AppMigrationHandoffStore.save(nil)
        defer { AppMigrationHandoffStore.save(nil) }
        var dependencies = AppMigrationCoordinatorDependencies()
        dependencies.role = .previousApp
        dependencies.open = { _ in true }
        dependencies.refreshLocalPushManagers = {}
        let coordinator = AppMigrationCoordinator(dependencies: dependencies)
        coordinator.handle(url: AppMigrationLink.request(.make()).url(to: .previousApp))
        defer { coordinator.declineExport() }
        assertLightDarkSnapshots(
            of: AppMigrationExportContainerView(coordinator: coordinator),
            named: "old-01b-export-container"
        )
    }

    @MainActor @Test func thePreviousAppRootsRefuseToOnboard() {
        AppMigrationRole.override = .previousApp
        defer { AppMigrationRole.override = nil }
        assertLightDarkSnapshots(
            of: OnboardingNavigationView(onboardingStyle: .required),
            named: "old-00d-root-required"
        )
        assertLightDarkSnapshots(
            of: OnboardingNavigationView(onboardingStyle: .secondary),
            named: "old-00e-root-secondary"
        )
    }

    @MainActor @Test func successRevealsTheCompletionDetails() async throws {
        let controller = UIHostingController(rootView: AppMigrationSuccessView(summary: .preview, continueAction: {}))
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        try await Task.sleep(for: .seconds(AppMigrationSuccessView.revealDelay + 1))
        assertLightDarkSnapshots(of: controller.rootView, named: "new-06b-success-revealed")
        window.isHidden = true
    }

    @MainActor @Test func migrationLinksReachTheCoordinatorThroughTheURLHandler() {
        defer { AppMigrationSessionStore.clearCompleted() }
        let completed = UUID()
        AppMigrationSessionStore.saveCompleted(completed)
        let handler = IncomingURLHandler(coordinator: MockAppCoordinator())
        #expect(handler.handle(url: AppMigrationLink.erased(sessionID: completed).url(to: .newApp)))
        #expect(!handler.handle(url: AppMigrationLink.erased(sessionID: UUID()).url(to: .newApp)))
        AppMigrationCoordinator.shared.finishImport()
    }

    // MARK: - Helpers

    private func importView(_ state: AppMigrationImportState) -> AppMigrationImportView {
        AppMigrationImportView(state: state, openPreviousAppAction: {}, retryAction: {}, cancelAction: {})
    }

    private func exportView(_ state: AppMigrationExportState) -> AppMigrationExportView {
        AppMigrationExportView(
            state: state,
            summary: .preview,
            transferAction: {},
            openNewAppAction: {},
            transferAgainAction: {},
            cancelAction: {},
            animatesErasedCheckmark: false
        )
    }
}
