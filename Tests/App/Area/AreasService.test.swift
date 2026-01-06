@testable import HomeAssistant
@testable import Shared
import Testing

// MARK: - Test Helpers

extension DeviceRegistryEntry {
    static func makeTest(
        areaId: String?,
        deviceId: String,
        configEntries: [String] = [],
        connections: [AnyCodable] = [],
        identifiers: [[String]] = [],
        name: String? = nil
    ) -> DeviceRegistryEntry {
        DeviceRegistryEntry(
            areaId: areaId,
            configurationURL: nil,
            configEntries: configEntries,
            configEntriesSubentries: [:],
            connections: connections,
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
    }
}

extension EntityRegistryEntry {
    static func makeTest(
        areaId: String?,
        entityId: String?,
        deviceId: String?,
        hiddenBy: String?,
        disabledBy: String?,
        uniqueId: String? = nil
    ) -> EntityRegistryEntry {
        EntityRegistryEntry(
            uniqueId: uniqueId ?? UUID().uuidString,
            entityId: entityId,
            platform: nil,
            configEntryId: nil,
            deviceId: deviceId,
            areaId: areaId,
            disabledBy: disabledBy,
            hiddenBy: hiddenBy,
            entityCategory: nil,
            name: nil,
            originalName: nil,
            icon: nil,
            originalIcon: nil,
            aliases: nil,
            labels: nil,
            deviceClass: nil,
            originalDeviceClass: nil,
            capabilities: nil,
            supportedFeatures: nil,
            unitOfMeasurement: nil,
            options: nil,
            translationKey: nil,
            hasEntityName: nil
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
}
