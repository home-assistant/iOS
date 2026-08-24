@testable import HomeAssistant
import SwiftUI
import Testing

struct AppMigrationStepRowTests {
    @MainActor
    @Test func pending() async throws {
        assertLightDarkSnapshots(of: row(state: .pending), named: "app-migration-step-row-pending")
    }

    @MainActor
    @Test func running() async throws {
        assertLightDarkSnapshots(of: row(state: .running), named: "app-migration-step-row-running")
    }

    @MainActor
    @Test func done() async throws {
        assertLightDarkSnapshots(of: row(state: .done), named: "app-migration-step-row-done")
    }

    @MainActor
    @Test func failed() async throws {
        assertLightDarkSnapshots(of: row(state: .failed), named: "app-migration-step-row-failed")
    }

    private func row(state: AppMigrationStepState) -> some View {
        List {
            AppMigrationStepRow(
                title: AppMigrationExportStep.servers.title,
                icon: AppMigrationExportStep.servers.icon,
                state: state
            )
        }
    }
}
