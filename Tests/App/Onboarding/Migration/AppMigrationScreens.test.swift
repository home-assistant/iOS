@testable import HomeAssistant
import Shared
import SnapshotTesting
import SwiftUI
import Testing

/// Every screen of the transfer, on both sides of the handoff, in every state it can land in.
struct AppMigrationScreensTests {
    private static let failure = "The previous app sent an incomplete transfer."

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

    @MainActor @Test func waitingForPreviousApp() {
        assertLightDarkSnapshots(of: importView(.waitingForPreviousApp), named: "new-04-waiting")
    }

    @MainActor @Test func importProgress() {
        assertLightDarkSnapshots(of: importView(.applying), named: "new-05-progress")
    }

    @MainActor @Test func importFailed() {
        assertLightDarkSnapshots(of: importView(.failed(message: Self.failure)), named: "new-06-failed")
    }

    @MainActor @Test func complete() {
        assertLightDarkSnapshots(
            of: AppMigrationCompleteView(summary: .preview, continueAction: {}),
            named: "new-07-complete"
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

    @MainActor @Test func exportRequested() {
        assertLightDarkSnapshots(of: exportView(.idle), named: "old-01-request")
    }

    @MainActor @Test func exportProgress() {
        assertLightDarkSnapshots(of: exportView(.preparing), named: "old-02-progress")
    }

    @MainActor @Test func exportHandedOff() {
        assertLightDarkSnapshots(of: exportView(.handedOff), named: "old-03-handed-off")
    }

    @MainActor @Test func exportFailed() {
        assertLightDarkSnapshots(
            of: exportView(.failed(message: "The new app is not installed on this device.")),
            named: "old-04-failed"
        )
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
            cancelAction: {}
        )
    }
}
