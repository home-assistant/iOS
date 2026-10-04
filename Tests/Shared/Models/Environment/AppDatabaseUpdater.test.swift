import Foundation
import GRDB
import HAKit
@testable import Shared
import UIKit
import XCTest

/// Drives a full `AppDatabaseUpdater` run against a connection that answers from canned responses,
/// so each step's persistence (registries, areas, entities, calendars) can be checked in an
/// in-memory database.
final class AppDatabaseUpdaterTests: XCTestCase {
    private var database: DatabaseQueue!
    private var connection: CannedResponseHAConnection!
    private var server: Server!
    private var updater: AppDatabaseUpdater!
    private var areasProvider: FakeAreasProvider!
    private var appEntitiesModel: FakeAppEntitiesModel!
    private var calendarsModel: FakeCalendarsModel!
    private var iconsService: EntityComponentIconsService!
    private var events: EventRecorder!

    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousApplication: (() -> UIApplication)?
    private var previousAreasProvider: (() -> AreasServiceProtocol)!
    private var previousAppEntitiesModel: (() -> AppEntitiesModelProtocol)!
    private var previousCalendarsModel: (() -> HACalendarsModelProtocol)!
    private var previousEntityComponentIcons: (() -> EntityComponentIconsProviderProtocol)!
    private var previousClientEventStore: ClientEventStoreProtocol!
    private var previousRefreshNetworkInformation: (() async -> Void)!

    override func setUpWithError() throws {
        try super.setUpWithError()

        database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }

        server = Server.fake(identifier: .init(rawValue: "app-database-updater-\(UUID().uuidString)")) { info in
            info.version = Version(major: 2024, minor: 10, patch: 0)
        }
        connection = CannedResponseHAConnection()
        let api = HomeAssistantAPI(server: server)
        api.connection = connection

        areasProvider = FakeAreasProvider()
        appEntitiesModel = FakeAppEntitiesModel()
        calendarsModel = FakeCalendarsModel()
        iconsService = EntityComponentIconsService()
        events = EventRecorder()

        previousDatabase = Current.database
        previousApplication = Current.application
        previousAreasProvider = Current.areasProvider
        previousAppEntitiesModel = Current.appEntitiesModel
        previousCalendarsModel = Current.calendarsModel
        previousEntityComponentIcons = Current.entityComponentIcons
        previousClientEventStore = Current.clientEventStore
        previousRefreshNetworkInformation = Current.connectivity.refreshNetworkInformation

        let database = database!
        let areasProvider = areasProvider!
        let appEntitiesModel = appEntitiesModel!
        let calendarsModel = calendarsModel!
        let iconsService = iconsService!
        let events = events!
        Current.database = { database }
        Current.application = { UIApplication.shared }
        Current.areasProvider = { areasProvider }
        Current.appEntitiesModel = { appEntitiesModel }
        Current.calendarsModel = { calendarsModel }
        Current.entityComponentIcons = { iconsService }
        Current.clientEventStore = MockClientEventStore { event in events.append(event.text) }
        Current.connectivity.refreshNetworkInformation = {}
        Current.setCachedApi(api, for: server.identifier)

        updater = AppDatabaseUpdater()
        // The updater seeds its foreground state on the main queue; let that run before updating.
        let seeded = expectation(description: "foreground state seeded")
        DispatchQueue.main.async { seeded.fulfill() }
        wait(for: [seeded], timeout: 5)
    }

    override func tearDown() {
        updater?.stop()
        updater = nil
        if let server {
            Current.resetAPICache(for: [server.identifier])
        }
        Current.database = previousDatabase
        Current.application = previousApplication
        Current.areasProvider = previousAreasProvider
        Current.appEntitiesModel = previousAppEntitiesModel
        Current.calendarsModel = previousCalendarsModel
        Current.entityComponentIcons = previousEntityComponentIcons
        Current.clientEventStore = previousClientEventStore
        Current.connectivity.refreshNetworkInformation = previousRefreshNetworkInformation
        super.tearDown()
    }

    // MARK: - Tests

    func testFullUpdatePersistsEveryStep() throws {
        connection.responses = Self.responses(deviceNames: ["Hub"])
        areasProvider.configure(serverId: server.identifier.rawValue)

        let phases = PhaseRecorder(server: server)
        defer { phases.stop() }

        runUpdate(forceUpdate: true)

        let serverId = server.identifier.rawValue

        let registry = try EntityRegistryListForDisplay.Entity.config(serverId: serverId)
        XCTAssertEqual(registry.map(\.entityId), ["light.kitchen"])
        XCTAssertEqual(registry.first?.serverId, serverId)
        XCTAssertEqual(registry.first?.name, "Kitchen light")

        let devices = try AppDeviceRegistry.config(serverId: serverId)
        XCTAssertEqual(devices.map(\.deviceId), ["device-0"])
        XCTAssertEqual(devices.first?.name, "Hub")

        let areas = try AppArea.fetchAreas(for: serverId)
        XCTAssertEqual(areas.map(\.areaId), ["kitchen", "garden"])
        XCTAssertEqual(areas.first?.floorName, "Ground floor")
        XCTAssertEqual(areas.first?.entities, ["light.kitchen"])
        XCTAssertNil(areas.last?.floorName)
        XCTAssertEqual(areas.last?.entities, [])

        XCTAssertEqual(appEntitiesModel.receivedEntityIds, ["calendar.family", "light.kitchen"])
        XCTAssertEqual(calendarsModel.receivedEntityIds, ["calendar.family", "light.kitchen"])
        XCTAssertEqual(iconsService.iconsMap(for: serverId)?["light"]?["_"]?.defaultIcon, "mdi:lightbulb")

        XCTAssertEqual(phases.descriptions, [
            L10n.Settings.ConnectionSection.UpdateDatabase.Progress.entities,
            L10n.Settings.ConnectionSection.UpdateDatabase.Progress.devices,
            L10n.Settings.ConnectionSection.UpdateDatabase.Progress.areas,
            L10n.Settings.ConnectionSection.UpdateDatabase.Progress.calendars,
        ])
        XCTAssertEqual(connection.sentCommands, [
            "states",
            "config/entity_registry/list_for_display",
            "frontend/get_icons",
            "config/device_registry/list",
        ])
        XCTAssertTrue(events.texts.isEmpty)
    }

    func testRepeatedUpdateKeepsUnchangedDataAndReplacesChangedData() throws {
        connection.responses = Self.responses(deviceNames: ["Hub"])
        areasProvider.configure(serverId: server.identifier.rawValue)
        runUpdate(forceUpdate: true)

        // Same registry and areas, but a different device list.
        connection.responses = Self.responses(deviceNames: ["Bridge", "Speaker"])
        runUpdate(forceUpdate: true)

        let serverId = server.identifier.rawValue
        XCTAssertEqual(
            try EntityRegistryListForDisplay.Entity.config(serverId: serverId).map(\.entityId),
            ["light.kitchen"]
        )
        XCTAssertEqual(
            try AppDeviceRegistry.config(serverId: serverId).compactMap(\.name).sorted(),
            ["Bridge", "Speaker"]
        )
        XCTAssertEqual(try AppArea.fetchAreas(for: serverId).map(\.areaId), ["kitchen", "garden"])
        XCTAssertEqual(connection.sentCommands.filter { $0 == "states" }.count, 2)
    }

    func testFailedRequestsAreRecordedAndTheRoutineStillFinishes() throws {
        // No canned responses: every request fails.
        areasProvider.configure(serverId: server.identifier.rawValue)

        runUpdate(forceUpdate: false)

        let serverId = server.identifier.rawValue
        XCTAssertTrue(try EntityRegistryListForDisplay.Entity.config(serverId: serverId).isEmpty)
        XCTAssertTrue(try AppDeviceRegistry.config(serverId: serverId).isEmpty)
        // Areas come from the areas provider rather than the connection, so they are still saved.
        XCTAssertEqual(try AppArea.fetchAreas(for: serverId).map(\.areaId), ["kitchen", "garden"])
        XCTAssertNil(appEntitiesModel.receivedEntityIds)
        XCTAssertNil(calendarsModel.receivedEntityIds)
        XCTAssertNil(iconsService.iconsMap(for: serverId))

        let texts = events.texts
        XCTAssertTrue(texts.contains("Failed to fetch states on server \(server.info.name)"))
        XCTAssertTrue(texts.contains("Failed to fetch EntityRegistryListForDisplay on server \(server.info.name)"))
        XCTAssertTrue(texts.contains("Failed to fetch device registry on server \(server.info.name)"))
    }

    func testServerWithoutAreasSkipsTheAreasWrite() throws {
        connection.responses = Self.responses(deviceNames: ["Hub"])
        // Areas provider left empty: nothing known for this server.

        runUpdate(forceUpdate: true)

        let serverId = server.identifier.rawValue
        XCTAssertTrue(try AppArea.fetchAreas(for: serverId).isEmpty)
        XCTAssertEqual(try AppDeviceRegistry.config(serverId: serverId).count, 1)
    }

    // MARK: - Helpers

    private func runUpdate(forceUpdate: Bool) {
        let server = server!
        let finished = expectation(forNotification: .appDatabaseUpdaterDidFinishRoutine, object: nil) { notification in
            (notification.object as? Server) === server
        }
        updater.update(server: server, forceUpdate: forceUpdate, showProgress: false)
        wait(for: [finished], timeout: 10)
    }

    private static func responses(deviceNames: [String]) -> [String: HAData] {
        [
            "states": .array([
                .dictionary([
                    "entity_id": "light.kitchen",
                    "state": "on",
                    "last_changed": "2026-04-23T10:00:00Z",
                    "last_updated": "2026-04-23T10:00:00Z",
                    "attributes": ["friendly_name": "Kitchen light"],
                    "context": ["id": "context-1"],
                ]),
                .dictionary([
                    "entity_id": "calendar.family",
                    "state": "off",
                    "last_changed": "2026-04-23T10:00:00Z",
                    "last_updated": "2026-04-23T10:00:00Z",
                    "attributes": ["friendly_name": "Family"],
                    "context": ["id": "context-2"],
                ]),
            ]),
            "config/entity_registry/list_for_display": .dictionary([
                "entity_categories": ["0": "config", "1": "diagnostic"],
                "entities": [
                    ["ei": "light.kitchen", "en": "Kitchen light", "pl": "hue", "ai": "kitchen"],
                ],
            ]),
            "frontend/get_icons": .dictionary([
                "resources": [
                    "light": ["_": ["default": "mdi:lightbulb"]],
                ],
            ]),
            "config/device_registry/list": .array(deviceNames.enumerated().map { index, name in
                .dictionary([
                    "id": "device-\(index)",
                    "name": name,
                    "area_id": "kitchen",
                ])
            }),
        ]
    }

    // MARK: - Fakes

    private final class FakeAreasProvider: AreasServiceProtocol {
        private(set) var areas: [String: [HAAreasRegistryResponse]] = [:]
        private(set) var floors: [String: [HAFloorRegistryResponse]] = [:]
        private var areasAndEntities: [String: Set<String>] = [:]

        func configure(serverId: String) {
            areas[serverId] = [
                HAAreasRegistryResponse(aliases: ["Cooking"], areaId: "kitchen", name: "Kitchen", floorId: "ground"),
                HAAreasRegistryResponse(aliases: [], areaId: "garden", name: "Garden", floorId: "unknown-floor"),
            ]
            floors[serverId] = [
                HAFloorRegistryResponse(aliases: [], floorId: "ground", name: "Ground floor"),
            ]
            areasAndEntities = ["kitchen": ["light.kitchen"]]
        }

        func fetchAreasAndItsEntities(for server: Server) async -> [String: Set<String>] {
            areasAndEntities
        }

        func area(for areaId: String, serverId: String) -> HAAreasRegistryResponse? {
            areas[serverId]?.first(where: { $0.areaId == areaId })
        }

        func floor(for floorId: String, serverId: String) -> HAFloorRegistryResponse? {
            floors[serverId]?.first(where: { $0.floorId == floorId })
        }
    }

    private final class FakeAppEntitiesModel: AppEntitiesModelProtocol {
        private let lock = NSLock()
        private var entityIds: [String]?

        var receivedEntityIds: [String]? {
            lock.lock()
            defer { lock.unlock() }
            return entityIds
        }

        func updateModel(_ entities: Set<HAEntity>, server: Server) async {
            lock.lock()
            defer { lock.unlock() }
            entityIds = entities.map(\.entityId).sorted()
        }
    }

    private final class FakeCalendarsModel: HACalendarsModelProtocol {
        private let lock = NSLock()
        private var entityIds: [String]?

        var receivedEntityIds: [String]? {
            lock.lock()
            defer { lock.unlock() }
            return entityIds
        }

        func updateModel(_ entities: [HAEntity], server: Server) async {
            lock.lock()
            defer { lock.unlock() }
            entityIds = entities.map(\.entityId).sorted()
        }

        func refresh(server: Server) async -> Bool {
            true
        }

        func events(for calendar: HACalendar, start: Date, end: Date) async -> [HACalendarEvent] {
            []
        }
    }

    private final class EventRecorder {
        private let lock = NSLock()
        private var underlyingTexts: [String] = []

        var texts: [String] {
            lock.lock()
            defer { lock.unlock() }
            return underlyingTexts
        }

        func append(_ text: String) {
            lock.lock()
            defer { lock.unlock() }
            underlyingTexts.append(text)
        }
    }

    /// Collects the phase descriptions broadcast for one server, in order.
    private final class PhaseRecorder {
        private let lock = NSLock()
        private var underlyingDescriptions: [String] = []
        private var token: NSObjectProtocol?

        var descriptions: [String] {
            lock.lock()
            defer { lock.unlock() }
            return underlyingDescriptions
        }

        init(server: Server) {
            token = NotificationCenter.default.addObserver(
                forName: .appDatabaseUpdaterDidChangePhase,
                object: nil,
                queue: nil
            ) { [weak self] notification in
                guard let self, (notification.object as? Server) === server,
                      let description = notification
                      .userInfo?[AppDatabaseUpdaterUserInfo.phaseDescriptionKey] as? String else {
                    return
                }
                lock.lock()
                underlyingDescriptions.append(description)
                lock.unlock()
            }
        }

        func stop() {
            if let token {
                NotificationCenter.default.removeObserver(token)
            }
            token = nil
        }
    }
}
