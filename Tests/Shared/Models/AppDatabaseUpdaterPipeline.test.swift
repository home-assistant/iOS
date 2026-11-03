import Foundation
import GRDB
import HAKit
@testable import Shared
import SharedTesting
import Testing
import UIKit

/// Runs `AppDatabaseUpdater`'s full update pipeline against a connection that answers each request as
/// it is sent, and an in-memory database. The updater works on detached tasks that read the global
/// `Current`, so the suite swaps the global environment and serializes with every other shared-state
/// test. A run that does not finish in time is stopped and drained before the test restores `Current`.
@Suite(.sharedState)
struct AppDatabaseUpdaterPipelineTests {
    // MARK: - Fixture

    private final class Flag: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0
        func fire() { lock.lock(); count += 1; lock.unlock() }
        var value: Int { lock.lock(); defer { lock.unlock() }; return count }
    }

    private final class StubIcons: EntityComponentIconsProviderProtocol {
        var fetched = 0
        func iconsMap(for serverId: String) -> EntityComponentIconsMap? { nil }
        func fetch(for server: Server) async -> EntityComponentIconsMap? {
            fetched += 1
            return nil
        }
    }

    private final class StubEntities: AppEntitiesModelProtocol {
        var received: [Set<HAEntity>] = []
        func updateModel(_ entities: Set<HAEntity>, server: Server) async {
            received.append(entities)
        }
    }

    private final class StubAreas: AreasServiceProtocol {
        var areas: [String: [HAAreasRegistryResponse]] = [:]
        var floors: [String: [HAFloorRegistryResponse]] = [:]
        var areaEntities: [String: Set<String>] = [:]
        func fetchAreasAndItsEntities(for server: Server) async -> [String: Set<String>] { areaEntities }
        func area(for areaId: String, serverId: String) -> HAAreasRegistryResponse? { nil }
        func floor(for floorId: String, serverId: String) -> HAFloorRegistryResponse? { nil }
    }

    private final class Fixture {
        let server = Server.fake()
        let database: DatabaseQueue
        let connection: RespondingHAConnection
        let icons = StubIcons()
        let entities = StubEntities()
        let areas = StubAreas()

        private let previousDatabase = Current.database
        private let previousCachedApis = Current.cachedApis
        private let previousIcons = Current.entityComponentIcons
        private let previousEntities = Current.appEntitiesModel
        private let previousAreas = Current.areasProvider
        private let previousCalendars = Current.calendarsModel

        /// - Parameter failRequests: whether every request fails instead of returning its fixture.
        init(failRequests: Bool = false) throws {
            // Every request is answered the moment it is sent, so the pipeline never waits on one.
            self.connection = RespondingHAConnection { request in
                failRequests
                    ? .failure(.internal(debugDescription: "offline"))
                    : .success(Fixture.response(for: request.type))
            }
            database = try DatabaseQueue()
            for table in DatabaseQueue.tables() {
                try table.createIfNeeded(database: database)
            }
            let database = database
            Current.database = { database }
            let api = HomeAssistantAPI(server: server)
            api.connection = connection
            Current.cachedApis[server.identifier] = api
            let icons = icons, entities = entities, areas = areas
            Current.entityComponentIcons = { icons }
            Current.appEntitiesModel = { entities }
            Current.areasProvider = { areas }
            Current.calendarsModel = { HACalendarsModel() }
        }

        func restore() {
            Current.database = previousDatabase
            Current.cachedApis = previousCachedApis
            Current.entityComponentIcons = previousIcons
            Current.appEntitiesModel = previousEntities
            Current.areasProvider = previousAreas
            Current.calendarsModel = previousCalendars
        }

        var serverId: String { server.identifier.rawValue }

        private static func response(for type: HARequestType) -> HAData {
            switch type {
            case .rest(.get, "states"):
                return .array([
                    entity("calendar.work", state: "off", name: "Work"),
                    entity("calendar.home", state: "on", name: "Home"),
                    entity("calendar.broken", state: "unavailable", name: "Broken"),
                    entity("calendar.hidden", state: "off", name: "Hidden"),
                    entity("light.kitchen", state: "on", name: "Kitchen"),
                ])
            case .webSocket("config/entity_registry/list_for_display"):
                return .dictionary([
                    "entity_categories": ["0": "config", "1": "diagnostic"],
                    "entities": [
                        ["ei": "calendar.work", "en": "Office", "pl": "local_calendar"],
                        ["ei": "calendar.hidden", "hb": true],
                        ["ei": "light.kitchen", "di": "device-1", "ai": "kitchen"],
                    ],
                ])
            case .webSocket("config/device_registry/list"):
                return .array([
                    .dictionary(["id": "device-1", "name": "Hub", "area_id": "kitchen"]),
                    .dictionary(["id": "device-2", "name": "Child", "via_device_id": "device-1"]),
                ])
            default:
                return .empty
            }
        }

        private static func entity(_ id: String, state: String, name: String) -> HAData {
            .dictionary([
                "entity_id": id,
                "state": state,
                "last_changed": "2026-01-01T00:00:00.000000+00:00",
                "last_updated": "2026-01-01T00:00:00.000000+00:00",
                "attributes": ["friendly_name": name, "supported_features": 3],
                "context": ["id": "ctx", "user_id": NSNull(), "parent_id": NSNull()],
            ])
        }
    }

    /// The updater seeds its foreground flag from `Current.application`, which a logic test bundle
    /// doesn't have; activate it the way the app does once its scene becomes active.
    private func activate() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
                continuation.resume()
            }
        }
    }

    private func observeFinish(of serverId: String) -> (Flag, NSObjectProtocol) {
        let flag = Flag()
        let token = NotificationCenter.default.addObserver(
            forName: .appDatabaseUpdaterDidFinishServer,
            object: nil,
            queue: nil
        ) { note in
            if note.userInfo?[AppDatabaseUpdaterUserInfo.serverIdentifierKey] as? String == serverId {
                flag.fire()
            }
        }
        return (flag, token)
    }

    /// Polls `condition` every 10 ms until it holds or `seconds` pass; returns whether it held.
    private func poll(seconds: TimeInterval, until condition: () async -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if await condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return await condition()
    }

    /// Whether the updater has dropped the server from its queue: a finished run reports finishing a
    /// moment before it leaves the queue, and an update requested in between is skipped as a duplicate.
    private func isIdle(_ updater: AppDatabaseUpdater, _ fixture: Fixture) async -> Bool {
        let coordinator = updater.taskCoordinator
        let force = await coordinator.effectiveForce(for: fixture.serverId)
        let showProgress = await coordinator.effectiveShowProgress(for: fixture.serverId)
        return !force && !showProgress
    }

    /// Requests an update and waits until it reports finishing and has left the updater's queue, at most
    /// ten seconds for each. On timeout the updater is stopped and given a few more seconds to wind down,
    /// so no run is left reading `Current` after the test restores it, and the test fails here.
    private func run(
        _ updater: AppDatabaseUpdater,
        _ fixture: Fixture,
        force: Bool = true,
        showProgress: Bool = false,
        expectedFinishes: Int
    ) async throws -> Int {
        let (flag, token) = observeFinish(of: fixture.serverId)
        defer { NotificationCenter.default.removeObserver(token) }
        updater.update(server: fixture.server, forceUpdate: force, showProgress: showProgress)
        var finished = await poll(seconds: 10) { flag.value >= expectedFinishes }
        if finished {
            finished = await poll(seconds: 10) { await isIdle(updater, fixture) }
        }
        if !finished {
            // Cancel the run and wait for it to report finishing (or for the stop to discard it).
            updater.stop()
            _ = await poll(seconds: 5) { flag.value >= expectedFinishes }
            _ = await poll(seconds: 5) { await isIdle(updater, fixture) }
        }
        try #require(finished, "pipeline did not finish")
        return flag.value
    }

    // MARK: - Tests

    @Test func fullUpdatePersistsRegistriesAreasAndCalendars() async throws {
        let fixture = try Fixture()
        defer { fixture.restore() }
        fixture.areas.areas[fixture.serverId] = [
            HAAreasRegistryResponse(aliases: [], areaId: "kitchen", name: "Kitchen", floorId: "ground"),
            HAAreasRegistryResponse(aliases: ["den"], areaId: "living", name: "Living"),
        ]
        fixture.areas.floors[fixture.serverId] = [
            HAFloorRegistryResponse(aliases: [], floorId: "ground", name: "Ground floor"),
        ]
        fixture.areas.areaEntities = ["kitchen": ["light.kitchen"]]

        let updater = AppDatabaseUpdater()
        await activate()
        _ = try await run(updater, fixture, showProgress: true, expectedFinishes: 1)

        let serverId = fixture.serverId
        let (areas, registry, devices, calendars) = try await fixture.database.read { db in
            try (
                AppArea.fetchAll(db),
                EntityRegistryListForDisplay.Entity.fetchAll(db),
                AppDeviceRegistry.fetchAll(db),
                HACalendar.fetchAll(db)
            )
        }
        #expect(Set(areas.map(\.areaId)) == ["kitchen", "living"])
        #expect(areas.first { $0.areaId == "kitchen" }?.floorName == "Ground floor")
        #expect(areas.first { $0.areaId == "kitchen" }?.entities == ["light.kitchen"])
        #expect(registry.map(\.entityId).sorted() == ["calendar.hidden", "calendar.work", "light.kitchen"])
        #expect(registry.allSatisfy { $0.serverId == serverId })
        #expect(Set(devices.map(\.deviceId)) == ["device-1", "device-2"])
        #expect(calendars.sorted { $0.sortOrder < $1.sortOrder }.map(\.entityId) == ["calendar.home", "calendar.work"])
        #expect(calendars.first { $0.entityId == "calendar.work" }?.name == "Office")
        #expect(fixture.icons.fetched == 1)
        #expect(fixture.entities.received.first?.count == 5)

        // A second forced run with identical data takes the "unchanged" shortcuts.
        _ = try await run(updater, fixture, expectedFinishes: 1)
        let areaCount = try await fixture.database.read { db in try AppArea.fetchCount(db) }
        #expect(areaCount == 2)

        // A non-forced run right after a success is throttled, but still reports finishing.
        _ = try await run(updater, fixture, force: false, expectedFinishes: 1)
        #expect(fixture.icons.fetched == 2)
    }

    @Test func failedRequestsLeaveTheDatabaseEmpty() async throws {
        let fixture = try Fixture(failRequests: true)
        defer { fixture.restore() }

        let updater = AppDatabaseUpdater()
        await activate()
        _ = try await run(updater, fixture, showProgress: true, expectedFinishes: 1)

        let (registry, devices, calendars) = try await fixture.database.read { db in
            try (
                EntityRegistryListForDisplay.Entity.fetchCount(db),
                AppDeviceRegistry.fetchCount(db),
                HACalendar.fetchCount(db)
            )
        }
        #expect(registry == 0)
        #expect(devices == 0)
        #expect(calendars == 0)
        #expect(fixture.entities.received.isEmpty)
    }

    @Test func backgroundedUpdaterDropsQueuedWork() async throws {
        let fixture = try Fixture()
        defer { fixture.restore() }

        let updater = AppDatabaseUpdater()
        await activate()
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
                continuation.resume()
            }
        }
        _ = try await run(updater, fixture, expectedFinishes: 1)
        #expect(fixture.connection.sentCommands.isEmpty)

        updater.stop()
        _ = try await run(updater, fixture, expectedFinishes: 1)
        #expect(fixture.connection.sentCommands.isEmpty)

        // Leave every other updater in the process foregrounded again.
        await activate()
    }
}
