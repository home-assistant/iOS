@testable import HomeAssistant
import SFSafeSymbols
import Shared
import Testing

struct AppMigrationProgressViewTests {
    @MainActor
    @Test func exportInProgress() async throws {
        let view = AppMigrationProgressView<AppMigrationExportStep>(
            symbol: .trayAndArrowUpFill,
            title: L10n.AppMigration.Progress.title,
            subtitle: L10n.AppMigration.Progress.subtitle,
            state: { step in
                switch step {
                case .servers: return .done
                case .configuration: return .running
                case .packaging, .handoff: return .pending
                }
            }
        )
        assertLightDarkSnapshots(of: view, named: "app-migration-export-in-progress")
    }

    @MainActor
    @Test func exportAllDone() async throws {
        let view = AppMigrationProgressView<AppMigrationExportStep>(
            symbol: .trayAndArrowUpFill,
            title: L10n.AppMigration.Progress.title,
            subtitle: L10n.AppMigration.Progress.subtitle,
            state: { _ in .done }
        )
        assertLightDarkSnapshots(of: view, named: "app-migration-export-all-done")
    }

    /// The configuration step is the one allowed to fail without stopping the migration, so the list
    /// has to read sensibly with a failure sitting between two successes.
    @MainActor
    @Test func exportWithFailedConfiguration() async throws {
        let view = AppMigrationProgressView<AppMigrationExportStep>(
            symbol: .trayAndArrowUpFill,
            title: L10n.AppMigration.Progress.title,
            subtitle: L10n.AppMigration.Progress.subtitle,
            state: { step in
                switch step {
                case .servers: return .done
                case .configuration: return .failed
                case .packaging: return .running
                case .handoff: return .pending
                }
            }
        )
        assertLightDarkSnapshots(of: view, named: "app-migration-export-failed-configuration")
    }

    /// The multi-link handoff: the bar only appears when a payload genuinely needs more than one
    /// round trip, so it is worth pinning that it does appear when it should.
    @MainActor
    @Test func exportTransferringChunks() async throws {
        let view = AppMigrationProgressView<AppMigrationExportStep>(
            symbol: .trayAndArrowUpFill,
            title: L10n.AppMigration.Progress.title,
            subtitle: L10n.AppMigration.Progress.subtitle,
            state: { step in
                switch step {
                case .servers, .configuration, .packaging: return .done
                case .handoff: return .running
                }
            },
            transfer: .init(completed: 2, total: 5),
            transferCaption: L10n.AppMigration.Transfer.caption(3, 5)
        )
        assertLightDarkSnapshots(of: view, named: "app-migration-export-transferring")
    }

    @MainActor
    @Test func importInProgress() async throws {
        let view = AppMigrationProgressView<AppMigrationImportStep>(
            symbol: .trayAndArrowDownFill,
            title: L10n.AppMigration.Import.Progress.title,
            subtitle: L10n.AppMigration.Import.Progress.subtitle,
            state: { step in
                switch step {
                case .reading, .servers: return .done
                case .configuration: return .running
                case .finishing: return .pending
                }
            }
        )
        assertLightDarkSnapshots(of: view, named: "app-migration-import-in-progress")
    }
}
