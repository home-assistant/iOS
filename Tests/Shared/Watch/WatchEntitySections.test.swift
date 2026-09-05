import GRDB
@testable import Shared
import Testing

/// Coverage for how the watch's area and device screens resolve a server's entities into their two
/// sections, and for the device each row carries — which is where child devices reach the watch.
struct WatchEntitySectionsTests {
    @Test("A child device's row carries its own name and the hardware it is part of")
    func rowCarriesTheParentOfAChildDevice() async throws {
        try await withFixture { sections in
            let outlet = try #require(
                Self.entries(of: sections.controls).first { $0.item.id == "switch.outlet_power" }?.device
            )
            #expect(outlet.name == "Outlet 2")
            #expect(outlet.parentId == "strip")
            #expect(outlet.parentName == "Power strip")

            let main = try #require(
                Self.entries(of: sections.controls).first { $0.item.id == "switch.strip_main" }?.device
            )
            #expect(main.name == "Power strip")
            #expect(main.parentName == nil)
        }
    }

    @Test("An entity of a device with no name is not attributed to it")
    func namelessDeviceIsNotAttributed() async throws {
        try await withFixture { sections in
            let unnamed = try #require(
                Self.entries(of: sections.controls).first { $0.item.id == "switch.unnamed" }
            )
            #expect(unnamed.device == nil)
        }
    }

    @Test("Sensors and controls land in their own sections")
    func splitsControlsFromSensors() async throws {
        try await withFixture { sections in
            #expect(Self.entries(of: sections.controls).map(\.item.id).sorted() == [
                "switch.outlet_power",
                "switch.strip_main",
                "switch.unnamed",
            ])
            #expect(Self.entries(of: sections.sensors).map(\.item.id) == ["sensor.strip_energy"])
        }
    }

    @Test("A parent device's screen includes the entities of its children")
    func parentDeviceIncludesItsChildren() async throws {
        try await withFixture(
            isIncluded: { _, device in device?.deviceId == "strip" || device?.parentDeviceId == "strip" }
        ) { sections in
            #expect(Self.entries(of: sections.controls).map(\.item.id).sorted() == [
                "switch.outlet_power",
                "switch.strip_main",
            ])
        }
    }

    // MARK: - Fixture

    /// One power strip with a child outlet and a nameless device, resolved through an in-memory
    /// database and a provider that names every entity after its id.
    private func withFixture(
        isIncluded: @escaping (HAAppEntity, AppDeviceRegistry?) -> Bool = { _, _ in true },
        assertions: (WatchEntitySections) throws -> Void
    ) async throws {
        let serverId = "1"
        let entities: [HAAppEntity] = [
            .make("switch.strip_main", domain: "switch", serverId: serverId),
            .make("switch.outlet_power", domain: "switch", serverId: serverId),
            .make("switch.unnamed", domain: "switch", serverId: serverId),
            .make("sensor.strip_energy", domain: "sensor", serverId: serverId),
        ]

        let previousDatabase = Current.database
        let previousProvider = Current.magicItemProvider
        let database = try DatabaseQueue(path: ":memory:")
        try DisplayEntityRegistryTable().createIfNeeded(database: database)
        try AppDeviceRegistryTable().createIfNeeded(database: database)
        Current.database = { database }
        Current.magicItemProvider = { WatchEntitySectionsProvider(entities: [serverId: entities]) }
        defer {
            Current.database = previousDatabase
            Current.magicItemProvider = previousProvider
        }

        try await database.write { db in
            try Self.registryEntry(entityId: "switch.strip_main", deviceId: "strip").insert(db)
            try Self.registryEntry(entityId: "sensor.strip_energy", deviceId: "strip").insert(db)
            try Self.registryEntry(entityId: "switch.outlet_power", deviceId: "outlet").insert(db)
            try Self.registryEntry(entityId: "switch.unnamed", deviceId: "unnamed").insert(db)
            try Self.device(deviceId: "strip", name: "Power strip").insert(db)
            try Self.device(deviceId: "outlet", name: "Outlet 2", parentDeviceId: "strip").insert(db)
            // Integrations do send devices with a blank name, e.g. UniFi clients.
            try Self.device(deviceId: "unnamed", name: "").insert(db)
        }

        let sections: WatchEntitySections = await withCheckedContinuation { continuation in
            WatchEntitySections.make(serverId: serverId, isIncluded: isIncluded) { sections in
                continuation.resume(returning: sections)
            }
        }
        try assertions(sections)
    }

    private static func entries(of grouped: WatchGroupedEntities) -> [WatchEntityEntry] {
        grouped.ungrouped + grouped.deviceGroups.flatMap(\.entries)
    }

    private static func registryEntry(entityId: String, deviceId: String) -> EntityRegistryListForDisplay.Entity {
        .init(serverId: "1", entityId: entityId, deviceId: deviceId)
    }

    private static func device(
        deviceId: String,
        name: String?,
        parentDeviceId: String? = nil
    ) -> AppDeviceRegistry {
        .init(
            serverId: "1",
            deviceId: deviceId,
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
            parentDeviceId: parentDeviceId,
            primaryConfigEntry: nil,
            serialNumber: nil,
            swVersion: nil,
            viaDeviceID: nil
        )
    }
}

private extension HAAppEntity {
    static func make(_ entityId: String, domain: String, serverId: String) -> HAAppEntity {
        .init(
            id: "\(serverId)-\(entityId)",
            entityId: entityId,
            serverId: serverId,
            domain: domain,
            name: entityId,
            icon: nil,
            rawDeviceClass: nil
        )
    }
}

private final class WatchEntitySectionsProvider: MagicItemProviderProtocol {
    private let entities: [String: [HAAppEntity]]

    init(entities: [String: [HAAppEntity]]) {
        self.entities = entities
    }

    func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
        completion(entities)
    }

    func loadInformation() async -> [String: [HAAppEntity]] {
        entities
    }

    func getInfo(for item: MagicItem) -> MagicItem.Info? {
        .init(id: item.serverUniqueId, name: item.id, iconName: "mdi:lightbulb")
    }

    func getAreaName(for item: MagicItem) -> String? {
        nil
    }
}
