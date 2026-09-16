import Foundation
import GRDB
import HAKit
import PromiseKit
@testable import Shared
import Testing

/// Serialized because every test swaps the global `Current.database` and `Current.backgroundTask`.
@Suite("PanelsUpdater database write", .serialized)
struct PanelsUpdaterSaveInDatabaseTests {
    /// Runs the wrapped work without a real `UIApplication`/`ProcessInfo` assertion.
    private final class PassthroughBackgroundTaskRunner: HomeAssistantBackgroundTaskRunner {
        func callAsFunction<PromiseValue>(
            withName name: String,
            wrapping: (TimeInterval?) -> Promise<PromiseValue>
        ) -> Promise<PromiseValue> {
            wrapping(nil)
        }
    }

    private func server(id: String) -> Server {
        let info = ServerInfo.fake()
        return Server(identifier: .init(rawValue: id), getter: { info }, setter: { _ in true })
    }

    private func panels(urlPaths: [String]) throws -> HAPanels {
        var value: [String: Any] = [:]
        for urlPath in urlPaths {
            value[urlPath] = [
                "component_name": "lovelace",
                "url_path": urlPath,
                "title": urlPath.capitalized,
                "icon": NSNull(),
                "show_in_sidebar": true,
            ]
        }
        return try HAPanels(data: HAData(value: value))
    }

    /// The write lands on a private queue, so the assertions poll rather than read straight after.
    private func waitUntil(_ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if condition() {
                return true
            }
            usleep(1000)
        }
        return condition()
    }

    private func withDatabase(_ body: (DatabaseQueue) throws -> Void) throws {
        let database = try DatabaseQueue()
        try AppPanelTable().createIfNeeded(database: database)

        let previousDatabase = Current.database
        let previousRunner = Current.backgroundTask
        Current.database = { database }
        Current.backgroundTask = PassthroughBackgroundTaskRunner()
        defer {
            Current.database = previousDatabase
            Current.backgroundTask = previousRunner
        }

        try body(database)
    }

    private func storedPaths(in database: DatabaseQueue, serverId: String) throws -> [String] {
        try database.read { db in
            try AppPanel
                .filter(Column(DatabaseTables.AppPanel.serverId.rawValue) == serverId)
                .fetchAll(db)
                .map(\.path)
                .sorted()
        }
    }

    @Test("Saves every panel of the server it was handed")
    func savesPanels() throws {
        try withDatabase { database in
            let updater = PanelsUpdater()

            try updater.saveInDatabase(panels(urlPaths: ["lovelace", "energy"]), server: server(id: "1"))

            #expect(waitUntil { (try? storedPaths(in: database, serverId: "1"))?.count == 2 })
            let paths = try storedPaths(in: database, serverId: "1")
            #expect(paths == ["energy", "lovelace"])
        }
    }

    @Test("Replaces the server's previous panels instead of accumulating them")
    func replacesPreviousPanels() throws {
        try withDatabase { database in
            let updater = PanelsUpdater()

            try updater.saveInDatabase(panels(urlPaths: ["lovelace", "energy"]), server: server(id: "1"))
            #expect(waitUntil { (try? storedPaths(in: database, serverId: "1"))?.count == 2 })

            try updater.saveInDatabase(panels(urlPaths: ["map"]), server: server(id: "1"))

            #expect(waitUntil { (try? storedPaths(in: database, serverId: "1")) == ["map"] })
            let paths = try storedPaths(in: database, serverId: "1")
            #expect(paths == ["map"])
        }
    }

    @Test("Leaves other servers' panels alone")
    func leavesOtherServersAlone() throws {
        try withDatabase { database in
            let updater = PanelsUpdater()

            try updater.saveInDatabase(panels(urlPaths: ["lovelace"]), server: server(id: "1"))
            #expect(waitUntil { (try? storedPaths(in: database, serverId: "1")) == ["lovelace"] })

            try updater.saveInDatabase(panels(urlPaths: ["energy"]), server: server(id: "2"))
            #expect(waitUntil { (try? storedPaths(in: database, serverId: "2")) == ["energy"] })

            let paths = try storedPaths(in: database, serverId: "1")
            #expect(paths == ["lovelace"])
        }
    }

    @Test("A failing write is logged rather than thrown out of the work queue")
    func failingWriteIsCaught() throws {
        let database = try DatabaseQueue()
        // No `AppPanelTable` created, so every statement fails on the missing table.
        let previousDatabase = Current.database
        let previousRunner = Current.backgroundTask
        Current.database = { database }
        Current.backgroundTask = PassthroughBackgroundTaskRunner()
        defer {
            Current.database = previousDatabase
            Current.backgroundTask = previousRunner
        }

        let updater = PanelsUpdater()
        try updater.saveInDatabase(panels(urlPaths: ["lovelace"]), server: server(id: "1"))

        // Nothing to assert beyond "the queue survived": a thrown error would trap the process.
        #expect(waitUntil {
            (try? database.read { db in try db.tableExists(GRDBDatabaseTable.appPanel.rawValue) }) == false
        })
    }
}
