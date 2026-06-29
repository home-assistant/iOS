@testable import HomeAssistant
@testable import Shared
import Testing

// MARK: - Test Helpers

extension AppDeviceRegistry {
    static func makeTest(
        areaId: String?,
        deviceId: String,
        serverId: String = "test-server",
        configEntries: [String]? = [],
        identifiers: [[String]]? = [],
        name: String? = nil
    ) -> AppDeviceRegistry {
        let entry = DeviceRegistryEntry(
            areaId: areaId,
            configurationURL: nil,
            configEntries: configEntries,
            configEntriesSubentries: [:],
            connections: nil,
            createdAt: 0.0,
            disabledBy: nil,
            entryType: "service",
            hwVersion: nil,
            id: deviceId,
            identifiers: identifiers,
            labels: [],
            manufacturer: nil,
            model: nil,
            modelID: nil,
            modifiedAt: 0.0,
            nameByUser: nil,
            name: name,
            primaryConfigEntry: nil,
            serialNumber: nil,
            swVersion: nil,
            viaDeviceID: nil
        )
        return AppDeviceRegistry(serverId: serverId, registry: entry)
    }
}

extension EntityRegistryListForDisplay.Entity {
    static func makeTest(
        areaId: String?,
        entityId: String,
        deviceId: String?,
        hiddenBy: String?,
        disabledBy: String? = nil,
        serverId: String = "test-server"
    ) -> EntityRegistryListForDisplay.Entity {
        EntityRegistryListForDisplay.Entity(
            serverId: serverId,
            entityId: entityId,
            deviceId: deviceId,
            entityCategory: nil,
            areaId: areaId,
            hidden: hiddenBy != nil ? true : nil
        )
    }
}

// MARK: - Tests

struct AreasServiceTests {
    @Test func validateGivenEntitiesAndDevicesReturnAreaAndContent() async throws {
        let result = AreasService().testGetAllEntitiesFromArea(
            devicesAndAreas: [
                .makeTest(areaId: "1", deviceId: "1"),
                .makeTest(areaId: "1", deviceId: "2"),
                .makeTest(areaId: "1", deviceId: "3"),
                .makeTest(areaId: "2", deviceId: "4"),
                .makeTest(areaId: "2", deviceId: "5"),
                .makeTest(areaId: "2", deviceId: "6"),
            ],
            entitiesAndAreas: [
                .makeTest(areaId: "1", entityId: "7", deviceId: "1", hiddenBy: nil, disabledBy: nil),
                .makeTest(areaId: "1", entityId: "8", deviceId: "1", hiddenBy: nil, disabledBy: nil),
                .makeTest(areaId: "1", entityId: "9", deviceId: "1", hiddenBy: nil, disabledBy: nil),
                .makeTest(areaId: "2", entityId: "10", deviceId: "4", hiddenBy: nil, disabledBy: nil),
                .makeTest(areaId: "2", entityId: "11", deviceId: "4", hiddenBy: nil, disabledBy: nil),
                .makeTest(areaId: nil, entityId: "12", deviceId: "1", hiddenBy: nil, disabledBy: nil),
                .makeTest(areaId: nil, entityId: "13", deviceId: "1", hiddenBy: nil, disabledBy: nil),
                .makeTest(areaId: nil, entityId: "14", deviceId: "4", hiddenBy: nil, disabledBy: nil),
                .makeTest(areaId: nil, entityId: "15", deviceId: "4", hiddenBy: nil, disabledBy: nil),
            ]
        )

        #expect(result == [
            "1": ["8", "12", "13", "9", "7"],
            "2": ["14", "11", "15", "10"],
        ])
    }

    @Test func floorLookupReturnsMatchingFloorForServer() {
        let service = AreasService()
        service.floors = [
            "server-a": [
                .init(aliases: [], floorId: "ground", name: "Ground Floor"),
                .init(aliases: [], floorId: "first", name: "First Floor"),
            ],
            "server-b": [
                .init(aliases: [], floorId: "ground", name: "Other Ground"),
            ],
        ]

        #expect(service.floor(for: "first", serverId: "server-a")?.name == "First Floor")
        // Same floorId on a different server resolves to that server's floor.
        #expect(service.floor(for: "ground", serverId: "server-b")?.name == "Other Ground")
    }

    @Test func floorLookupReturnsNilForUnknownFloorOrServer() {
        let service = AreasService()
        service.floors = [
            "server-a": [.init(aliases: [], floorId: "ground", name: "Ground Floor")],
        ]

        #expect(service.floor(for: "attic", serverId: "server-a") == nil)
        #expect(service.floor(for: "ground", serverId: "unknown-server") == nil)
    }
}
