import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

@MainActor
@Suite(.serialized)
struct SiriServerConfigurationViewModelTests {
    private func withSeededServer(_ body: (Server) async throws -> Void) async throws {
        let previous = Current.servers
        defer { Current.servers = previous }
        let manager = FakeServerManager(initial: 0)
        let server = manager.addFake()
        let other = manager.addFake()
        Current.servers = manager
        let serverId = server.identifier.rawValue
        try await SiriTestSeeding.clear(serverIds: [serverId, other.identifier.rawValue])
        try await SiriTestSeeding.seedCalendar(
            serverId: serverId,
            entityId: "calendar.home",
            name: "Home",
            sortOrder: 0
        )
        try await SiriTestSeeding.seedCalendar(
            serverId: serverId,
            entityId: "calendar.work",
            name: "Work",
            sortOrder: 1
        )
        try await SiriTestSeeding.seedTodoList(serverId: serverId, entityId: "todo.shopping", name: "Shopping")
        try await SiriTestSeeding.seedTodoList(serverId: serverId, entityId: "todo.chores", name: "Chores")
        try await SiriTestSeeding.seedTodoList(
            serverId: other.identifier.rawValue,
            entityId: "todo.other",
            name: "Other"
        )
        do {
            try await body(server)
        } catch {
            try await SiriTestSeeding.clear(serverIds: [serverId, other.identifier.rawValue])
            throw error
        }
        try await SiriTestSeeding.clear(serverIds: [serverId, other.identifier.rawValue])
    }

    @Test func loadsOnlyTheServersOwnCalendarsAndLists() async throws {
        try await withSeededServer { server in
            let model = SiriServerConfigurationViewModel(server: server, refresh: { _ in })
            model.load()
            let calendarNames = model.calendars.map(\.name)
            let listNames = model.lists.map(\.name)
            let everyCalendarExposed = model.calendars.allSatisfy(\.isExposed)
            let everyListExposed = model.lists.allSatisfy(\.isExposed)
            #expect(calendarNames == ["Home", "Work"])
            #expect(listNames == ["Chores", "Shopping"])
            #expect(everyCalendarExposed)
            #expect(everyListExposed)
            #expect(model.defaultCalendarId == nil)
            #expect(model.defaultListId == nil)
            #expect(model.serverName == server.info.name)
        }
    }

    @Test func switchingAListOffIsRememberedAndReloaded() async throws {
        try await withSeededServer { server in
            let model = SiriServerConfigurationViewModel(server: server, refresh: { _ in })
            model.load()
            let shopping = try #require(model.lists.first { $0.entityId == "todo.shopping" })

            model.setExposed(false, item: shopping, domain: .todo)

            let reloaded = SiriServerConfigurationViewModel(server: server, refresh: { _ in })
            reloaded.load()
            let shoppingAfter = reloaded.lists.first { $0.entityId == "todo.shopping" }
            let choresAfter = reloaded.lists.first { $0.entityId == "todo.chores" }
            #expect(shoppingAfter?.isExposed == false)
            #expect(choresAfter?.isExposed == true)
            let everyCalendarExposed = reloaded.calendars.allSatisfy(\.isExposed)
            #expect(everyCalendarExposed)
        }
    }

    @Test func pickingADefaultMarksThatOneAndClearingRemovesIt() async throws {
        try await withSeededServer { server in
            let model = SiriServerConfigurationViewModel(server: server, refresh: { _ in })
            model.load()
            let work = try #require(model.calendars.first { $0.entityId == "calendar.work" })
            let chores = try #require(model.lists.first { $0.entityId == "todo.chores" })

            model.setDefault(work.id, domain: .calendar)
            model.setDefault(chores.id, domain: .todo)
            #expect(model.defaultCalendarId == work.id)
            #expect(model.defaultListId == chores.id)

            model.setDefault(nil, domain: .calendar)
            #expect(model.defaultCalendarId == nil)
            #expect(model.defaultListId == chores.id)
        }
    }

    @Test func switchingOffTheDefaultListClearsTheDefault() async throws {
        try await withSeededServer { server in
            let model = SiriServerConfigurationViewModel(server: server, refresh: { _ in })
            model.load()
            let chores = try #require(model.lists.first { $0.entityId == "todo.chores" })
            model.setDefault(chores.id, domain: .todo)

            model.setExposed(false, item: chores, domain: .todo)

            #expect(model.defaultListId == nil)
        }
    }

    @Test func reloadAsksTheServerAndFinishesWhenItsRoutineDoes() async throws {
        try await withSeededServer { server in
            var refreshed: [Server] = []
            let model = SiriServerConfigurationViewModel(server: server, refresh: { refreshed.append($0) })
            model.load()

            model.reload()
            #expect(model.isReloading)
            let refreshedIds = refreshed.map(\.identifier)
            #expect(refreshedIds == [server.identifier])

            try await SiriTestSeeding.seedTodoList(
                serverId: server.identifier.rawValue,
                entityId: "todo.new",
                name: "New"
            )
            NotificationCenter.default.post(name: .appDatabaseUpdaterDidFinishRoutine, object: server)

            let deadline = Date().addingTimeInterval(5)
            while model.isReloading, Date() < deadline {
                try await Task.sleep(for: .milliseconds(20))
            }
            #expect(!model.isReloading)
            let listNames = model.lists.map(\.name)
            #expect(listNames == ["Chores", "New", "Shopping"])
        }
    }

    @Test func listsAreEmptyWhenTheDatabaseIsUnusable() async throws {
        try await withSeededServer { server in
            let previous = Current.database
            defer { Current.database = previous }
            let empty = try DatabaseQueue(path: ":memory:")
            Current.database = { empty }

            let model = SiriServerConfigurationViewModel(server: server, refresh: { _ in })
            model.load()

            #expect(model.lists.isEmpty)
            #expect(model.calendars.isEmpty)
        }
    }

    @Test func theDefaultRefreshGoesThroughTheAppDatabaseUpdater() async throws {
        try await withSeededServer { server in
            let previous = Current.appDatabaseUpdater
            defer { Current.appDatabaseUpdater = previous }
            let updater = RecordingSiriAppDatabaseUpdater()
            Current.appDatabaseUpdater = updater

            let model = SiriServerConfigurationViewModel(server: server)
            model.reload()

            #expect(updater.updates.map(\.serverId) == [server.identifier.rawValue])
            #expect(updater.updates.first?.forceUpdate == true)
            #expect(updater.updates.first?.showProgress == false)
        }
    }

    @Test func anotherServersRoutineDoesNotFinishTheReload() async throws {
        try await withSeededServer { server in
            let model = SiriServerConfigurationViewModel(server: server, refresh: { _ in })
            model.load()
            model.reload()

            NotificationCenter.default.post(name: .appDatabaseUpdaterDidFinishRoutine, object: Server.fake())
            try await Task.sleep(for: .milliseconds(100))

            #expect(model.isReloading)
        }
    }

    private final class RecordingSiriAppDatabaseUpdater: AppDatabaseUpdaterProtocol {
        struct Update {
            let serverId: String
            let forceUpdate: Bool
            let showProgress: Bool
        }

        private(set) var updates: [Update] = []

        func stop() {}

        func update(server: Server, forceUpdate: Bool, showProgress: Bool) {
            updates.append(Update(
                serverId: server.identifier.rawValue,
                forceUpdate: forceUpdate,
                showProgress: showProgress
            ))
        }
    }
}
