@testable import HomeAssistant
import Testing

struct AreaProviderTests {
    @Test func validateGivenEntitiesAndDevicesReturnAreaAndContent() async throws {
        let result = AreaProvider.getAllEntitiesFromArea(
            devicesAndAreas: [
                .init(areaId: "1", deviceId: "1"),
                .init(areaId: "1", deviceId: "2"),
                .init(areaId: "1", deviceId: "3"),
                .init(areaId: "2", deviceId: "4"),
                .init(areaId: "2", deviceId: "5"),
                .init(areaId: "2", deviceId: "6"),
            ],
            entitiesAndAreas: [
                .init(areaId: "1", entityId: "7", deviceId: "1"),
                .init(areaId: "1", entityId: "8", deviceId: "1"),
                .init(areaId: "1", entityId: "9", deviceId: "1"),
                .init(areaId: "2", entityId: "10", deviceId: "4"),
                .init(areaId: "2", entityId: "11", deviceId: "4"),
                .init(areaId: nil, entityId: "12", deviceId: "1"),
                .init(areaId: nil, entityId: "13", deviceId: "1"),
                .init(areaId: nil, entityId: "14", deviceId: "4"),
                .init(areaId: nil, entityId: "15", deviceId: "4"),
            ]
        )

        #expect(result == [
            "1": ["8", "12", "13", "9", "7"],
            "2": ["14", "11", "15", "10"],
        ])
    }
}
