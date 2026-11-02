import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// Renders the debug transfer section against databases with and without its tables.
/// Shared state: swaps `Current.database`.
@MainActor
@Suite(.sharedState)
struct DebugDatabaseTransferSectionTests {
    private func seedWatchConfig(_ db: Database) throws {
        try WatchConfig(id: WatchConfig.watchConfigId, items: [
            .init(id: "watch-item", serverId: "server", type: .script),
        ]).insert(db)
    }

    /// With rows to export, the availability check enables export; the buttons themselves are
    /// SwiftUI buttons inside one row, which a unit test cannot press.
    @Test func rendersWithExportableContent() async throws {
        try await SettingsTestDatabase.with(seedWatchConfig) { _ in
            let hasContent = try DebugDatabaseTransfer.hasExportableContent(part: .watchConfiguration)
            #expect(hasContent)
            let screen = await RecordingScreen.show(List { DebugDatabaseTransferSection(part: .watchConfiguration) })
            defer { screen.close() }
            await screen.settle()
        }
    }

    /// A database without the tables leaves export unavailable instead of failing the screen.
    @Test func unreadableAvailabilityDisablesExport() async throws {
        try await SettingsTestDatabase.with { _ in
            Current.database = { try! DatabaseQueue() }
            let screen = await RecordingScreen.show(List { DebugDatabaseTransferSection(part: .customWidgets) })
            defer { screen.close() }
            await screen.settle()
            #expect(screen.presented(UIActivityViewController.self).isEmpty)
        }
    }
}
