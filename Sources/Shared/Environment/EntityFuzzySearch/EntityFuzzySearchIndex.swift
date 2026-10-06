import Foundation
import GRDB

public struct EntityFuzzySearchIndex {
    private static let keys: [FuzzyKey] = [
        FuzzyKey(name: "name", weight: 10),
        FuzzyKey(name: "deviceName", weight: 7),
        FuzzyKey(name: "parentDeviceName", weight: 6),
        FuzzyKey(name: "areaName", weight: 6),
        FuzzyKey(name: "domainName", weight: 6),
        FuzzyKey(name: "floorName", weight: 5),
        FuzzyKey(name: "entityId", weight: 3),
    ]

    private let entities: [HAAppEntity]
    private let documents: [FuzzyDocument]
    private let searcher: FuzzySearcher

    public init(entities: [HAAppEntity], serverId: String) {
        self.entities = entities
        self.searcher = FuzzySearcher(keys: Self.keys)

        var areaNames: [String: String] = [:]
        var floorNames: [String: String] = [:]
        do {
            let areas = try AppArea.fetchAreas(for: serverId)
            for area in areas {
                for entityId in area.entities {
                    areaNames[entityId] = area.name
                    if let floorName = area.floorName, !floorName.isEmpty {
                        floorNames[entityId] = floorName
                    }
                }
            }
        } catch {
            Current.Log.error("Failed to fetch areas for entity fuzzy search: \(error)")
        }

        let (deviceNames, parentDeviceNames) = Self.deviceNames(for: serverId)

        self.documents = entities.map { entity in
            FuzzyDocument(id: entity.id, fieldValues: [
                entity.name,
                deviceNames[entity.entityId],
                parentDeviceNames[entity.entityId],
                areaNames[entity.entityId],
                Domain(rawValue: entity.domain)?.name ?? entity.domain,
                floorNames[entity.entityId],
                entity.entityId,
            ])
        }
    }

    public func search(_ query: String) -> [HAAppEntity] {
        searcher.search(query, in: documents).map { entities[$0] }
    }

    private static func deviceNames(
        for serverId: String
    ) -> (deviceNames: [String: String], parentDeviceNames: [String: String]) {
        do {
            let registries = try Current.database().read { db in
                try EntityRegistryListForDisplay.Entity
                    .filter(Column(DatabaseTables.DisplayEntityRegistry.serverId.rawValue) == serverId)
                    .fetchAll(db)
            }
            let devices = try Current.database().read { db in
                try AppDeviceRegistry
                    .filter(Column(DatabaseTables.DeviceRegistry.serverId.rawValue) == serverId)
                    .fetchAll(db)
            }
            let devicesByDeviceId = Dictionary(
                devices.map { ($0.deviceId, $0) },
                uniquingKeysWith: { first, _ in first }
            )

            var deviceNames: [String: String] = [:]
            var parentDeviceNames: [String: String] = [:]
            for registry in registries {
                guard let deviceId = registry.deviceId, let device = devicesByDeviceId[deviceId] else { continue }
                deviceNames[registry.entityId] = device.displayName
                parentDeviceNames[registry.entityId] = device.parentDeviceId.flatMap {
                    devicesByDeviceId[$0]?.displayName
                }
            }
            return (deviceNames, parentDeviceNames)
        } catch {
            Current.Log.error("Failed to build device names for entity fuzzy search: \(error)")
            return ([:], [:])
        }
    }
}
