import Foundation
import GRDB
@testable import Shared
import Testing

/// Serialized because every test swaps the global `Current.database` and `Current.magicItemProvider`.
@Suite(.serialized)
struct WatchEntitySectionsTests {
    /// Serves a fixed entity list and resolves info for every entity except the ones listed in
    /// `missingInfo`, synchronously.
    private final class StubProvider: MagicItemProviderProtocol {
        let entitiesPerServer: [String: [HAAppEntity]]
        let missingInfo: Set<String>

        init(entitiesPerServer: [String: [HAAppEntity]], missingInfo: Set<String> = []) {
            self.entitiesPerServer = entitiesPerServer
            self.missingInfo = missingInfo
        }

        func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
            completion(entitiesPerServer)
        }

        func loadInformation() async -> [String: [HAAppEntity]] {
            entitiesPerServer
        }

        func getInfo(for item: MagicItem) -> MagicItem.Info? {
            guard !missingInfo.contains(item.id),
                  let entity = entitiesPerServer[item.serverId]?.first(where: { $0.entityId == item.id }) else {
                return nil
            }
            return .init(id: entity.id, name: entity.name, iconName: "mdi:circle")
        }

        func getAreaName(for item: MagicItem) -> String? { nil }
    }

    private static let serverId = "1"

    private static func entity(_ entityId: String, name: String, isHidden: Bool? = nil) -> HAAppEntity {
        .init(
            id: "\(serverId)-\(entityId)",
            entityId: entityId,
            serverId: serverId,
            domain: String(entityId.split(separator: ".")[0]),
            name: name,
            icon: nil,
            rawDeviceClass: nil,
            entityCategory: nil,
            isHidden: isHidden
        )
    }

    private static func device(id: String, name: String) -> AppDeviceRegistry {
        AppDeviceRegistry(
            serverId: serverId,
            deviceId: id,
            areaId: nil,
            configurationURL: nil,
            configEntries: nil,
            configEntriesSubentries: nil,
            connections: nil,
            createdAt: nil,
            disabledBy: nil,
            entryType: nil,
            hwVersion: nil,
            identifiers: nil,
            labels: nil,
            manufacturer: nil,
            model: nil,
            modelID: nil,
            modifiedAt: nil,
            nameByUser: nil,
            name: name,
            primaryConfigEntry: nil,
            serialNumber: nil,
            swVersion: nil,
            viaDeviceID: nil
        )
    }

    private func withEnvironment(
        provider: StubProvider,
        perform work: (DatabaseQueue) throws -> Void
    ) throws {
        let previousDatabase = Current.database
        let previousProvider = Current.magicItemProvider
        let database = try DatabaseQueue(path: ":memory:")
        try DisplayEntityRegistryTable().createIfNeeded(database: database)
        try AppDeviceRegistryTable().createIfNeeded(database: database)
        Current.database = { database }
        Current.magicItemProvider = { provider }
        defer {
            Current.database = previousDatabase
            Current.magicItemProvider = previousProvider
        }

        try work(database)
    }

    private func makeSections(
        isIncluded: @escaping (HAAppEntity, AppDeviceRegistry?) -> Bool = { _, _ in true }
    ) -> WatchEntitySections? {
        var result: WatchEntitySections?
        WatchEntitySections.make(serverId: Self.serverId, isIncluded: isIncluded) { result = $0 }
        return result
    }

    @Test func splitsControlsFromSensorsAndOrdersByDomain() throws {
        let provider = StubProvider(entitiesPerServer: [Self.serverId: [
            Self.entity("switch.kettle", name: "Kettle"),
            Self.entity("light.kitchen", name: "Kitchen"),
            Self.entity("light.attic", name: "Attic"),
            Self.entity("sensor.temperature", name: "Temperature"),
            Self.entity("binary_sensor.door", name: "Door"),
            Self.entity("camera.porch", name: "Porch"),
            Self.entity("light.hidden", name: "Hidden", isHidden: true),
        ]])

        try withEnvironment(provider: provider) { _ in
            let sections = try #require(makeSections())

            #expect(sections.isEmpty == false)
            #expect(sections.controls.allEntries.map(\.item.id) == ["light.attic", "light.kitchen", "switch.kettle"])
            #expect(sections.sensors.allEntries.map(\.item.id) == ["binary_sensor.door", "sensor.temperature"])
            #expect(sections.controls.deviceGroups.isEmpty)
            #expect(sections.controls.allEntries.allSatisfy { $0.item.serverId == Self.serverId })
        }
    }

    @Test func registryExclusionsPredicateAndMissingInfoDropEntities() throws {
        let provider = StubProvider(
            entitiesPerServer: [Self.serverId: [
                Self.entity("light.kitchen", name: "Kitchen"),
                Self.entity("light.stale_hidden", name: "Stale"),
                Self.entity("lock.front", name: "Front"),
                Self.entity("switch.no_info", name: "No info"),
            ]],
            missingInfo: ["switch.no_info"]
        )

        try withEnvironment(provider: provider) { database in
            try database.write { db in
                try EntityRegistryListForDisplay.Entity(
                    serverId: Self.serverId,
                    entityId: "light.stale_hidden",
                    hidden: true
                ).insert(db)
            }

            let sections = try #require(makeSections(isIncluded: { entity, _ in entity.entityId != "lock.front" }))

            #expect(sections.controls.allEntries.map(\.item.id) == ["light.kitchen"])
            #expect(sections.sensors.isEmpty)
        }
    }

    @Test func entitiesSharingADeviceAreGroupedUnderIt() throws {
        let provider = StubProvider(entitiesPerServer: [Self.serverId: [
            Self.entity("light.desk", name: "Desk lamp"),
            Self.entity("switch.desk_fan", name: "Desk fan"),
            Self.entity("light.hall", name: "Hall"),
        ]])

        try withEnvironment(provider: provider) { database in
            try database.write { db in
                try Self.device(id: "desk", name: "Desk").insert(db)
                try EntityRegistryListForDisplay.Entity(
                    serverId: Self.serverId,
                    entityId: "light.desk",
                    deviceId: "desk"
                ).insert(db)
                try EntityRegistryListForDisplay.Entity(
                    serverId: Self.serverId,
                    entityId: "switch.desk_fan",
                    deviceId: "desk"
                ).insert(db)
            }

            var seenDevices: [String: String] = [:]
            let sections = try #require(makeSections(isIncluded: { entity, device in
                if let device {
                    seenDevices[entity.entityId] = device.deviceId
                }
                return true
            }))

            #expect(seenDevices == ["light.desk": "desk", "switch.desk_fan": "desk"])
            #expect(sections.controls.ungrouped.map(\.item.id) == ["light.hall"])
            #expect(sections.controls.deviceGroups.count == 1)
            let group = try #require(sections.controls.deviceGroups.first)
            #expect(group.deviceId == "desk")
            #expect(group.name == "Desk")
            #expect(group.entries.map(\.item.id) == ["light.desk", "switch.desk_fan"])
            #expect(group.entries.first?.device == WatchEntityEntry.Device(id: "desk", name: "Desk"))
        }
    }

    @Test func unknownServerResolvesToEmptySections() throws {
        try withEnvironment(provider: StubProvider(entitiesPerServer: [:])) { _ in
            let sections = try #require(makeSections())
            #expect(sections.isEmpty)
        }
    }

    @Test func emptyConstantIsEmpty() {
        #expect(WatchEntitySections.empty.isEmpty)
        let sections = WatchEntitySections(controls: .empty, sensors: .empty)
        #expect(sections.controls.isEmpty)
        #expect(sections.sensors.isEmpty)
    }
}
