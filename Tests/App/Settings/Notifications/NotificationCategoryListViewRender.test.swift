import GRDB
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Shared state: the list observes `Current.database` and its editors read `Current.apis`, both from
/// the main run loop, so they are swapped globally.
@Suite(.sharedState)
@MainActor
struct NotificationCategoryListViewRenderTests {
    @Test func rendersWithoutCategories() async throws {
        try await withWorld { _ in
            let driver = await show()
            defer { driver.close() }
            // Local section with only "Add"; server section with its empty-state row.
            #expect(driver.rowCount(inSection: 0) == 1)
            #expect(driver.rowCount(inSection: 1) == 1)
        }
    }

    /// Opens a local and a server category in the editor sheet, then adds a new one through it.
    /// Lists local and server-controlled categories in their own sections. The editor the rows open
    /// is a sheet, which an off-screen window never presents; NotificationCategoryEditorViewRenderTests
    /// covers it directly.
    @Test func listsLocalAndServerCategories() async throws {
        try await withWorld { database in
            try await database.write { db in
                try NotificationCategory(identifier: "local_one", name: "Local").insert(db)
                try NotificationCategory(identifier: "local_two", name: "").insert(db)
                try NotificationCategory(identifier: "remote", name: "Remote", isServerControlled: true).insert(db)
            }
            let driver = await show()
            defer { driver.close() }
            await #expect(driver.waitUntil { driver.rowCount(inSection: 0) == 3 })
            #expect(driver.rowCount(inSection: 1) == 1)
        }
    }

    /// Each category row, and "Add", only raise the editor sheet; the list itself is unchanged.
    @Test func rowsRaiseTheEditor() async throws {
        try await withWorld { database in
            try await database.write { db in
                try NotificationCategory(identifier: "local_one", name: "Local").insert(db)
                try NotificationCategory(identifier: "remote", name: "Remote", isServerControlled: true).insert(db)
            }
            let driver = await show()
            defer { driver.close() }
            await #expect(driver.waitUntil { driver.rowCount(inSection: 0) == 2 })

            for row in [IndexPath(item: 0, section: 0), IndexPath(item: 1, section: 0), IndexPath(
                item: 0,
                section: 1
            )] {
                await driver.tapRow(row)
                await driver.dismissPresented()
            }
            #expect(driver.rowCount(inSection: 0) == 2)
        }
    }

    /// The help button opens the actionable notifications documentation in the browser.
    @Test func helpOpensTheDocumentation() async throws {
        try await withWorld { _ in
            try await RecordingURLOpener.with { opener in
                let driver = await show()
                defer { driver.close() }
                try #require(!driver.barButtons.isEmpty)
                await driver.tapBarButton(0)
                #expect(opener.openedURLs.map(\.url.absoluteString) == [
                    "https://companion.home-assistant.io/app/ios/actionable-notifications",
                ])
            }
        }
    }

    private func show() async -> SwiftUIScreenDriver {
        await SwiftUIScreenDriver.show(
            NotificationCategoryListView()
                .environmentObject(ViewControllerProvider())
        )
    }

    private func withWorld(_ body: (DatabaseQueue) async throws -> Void) async throws {
        let database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        let previousDatabase = Current.database
        let previousServers = Current.servers
        let servers = FakeServerManager(initial: 1)
        let api = HomeAssistantAPI(server: servers.all[0])
        api.connection = HAMockConnection()
        Current.setCachedApi(api, for: servers.all[0].identifier)
        Current.servers = servers
        Current.database = { database }
        defer {
            Current.resetAPICache(for: servers.all.map(\.identifier))
            Current.servers = previousServers
            Current.database = previousDatabase
        }
        try await body(database)
    }
}
