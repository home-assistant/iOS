import HAKit
@testable import Shared
import Testing

struct WatchEntityDetailsTests {
    private func makeEntity(
        entityId: String = "sensor.living_room_temperature",
        state: String = "21.4",
        attributes: [String: Any] = [:],
        lastChanged: Date = Date(timeIntervalSince1970: 1000),
        lastUpdated: Date = Date(timeIntervalSince1970: 2000)
    ) throws -> HAEntity {
        try HAEntity(
            entityId: entityId,
            state: state,
            lastChanged: lastChanged,
            lastUpdated: lastUpdated,
            attributes: attributes,
            context: .init(id: "context", userId: nil, parentId: nil)
        )
    }

    @Test func stateIncludesUnitAndNameComesFromFriendlyName() throws {
        let entity = try makeEntity(attributes: [
            "friendly_name": "Living room temperature",
            "unit_of_measurement": "°C",
        ])
        let details = WatchEntityDetails(entity: entity)

        #expect(details.entityId == "sensor.living_room_temperature")
        #expect(details.name == "Living room temperature")
        #expect(details.state == "21.4 °C")
        #expect(details.lastChanged == Date(timeIntervalSince1970: 1000))
        #expect(details.lastUpdated == Date(timeIntervalSince1970: 2000))
    }

    @Test func nameFallsBackToEntityIdWithoutFriendlyName() throws {
        let details = try WatchEntityDetails(entity: makeEntity())

        #expect(details.name == "sensor.living_room_temperature")
    }

    @Test func binarySensorStateUsesDeviceClassDescription() throws {
        let entity = try makeEntity(
            entityId: "binary_sensor.front_door",
            state: "on",
            attributes: ["device_class": "door"]
        )
        let details = WatchEntityDetails(entity: entity)

        #expect(details.state == CoreStrings.componentBinarySensorEntityComponentDoorStateOn)
        #expect(details.deviceClass == "Door")
    }

    @Test func deviceClassIsHumanizedAndKeptEvenWhenUnknownToTheApp() throws {
        let entity = try makeEntity(attributes: ["device_class": "not_a_real_device_class"])
        let details = WatchEntityDetails(entity: entity)

        #expect(details.deviceClass == "Not a real device class")
        // Shown in its own row, so it must not also appear as an attribute.
        #expect(!details.attributes.contains(where: { $0.id == "device_class" }))
    }

    @Test func noDeviceClassAttributeMeansNoDeviceClass() throws {
        let details = try WatchEntityDetails(entity: makeEntity())

        #expect(details.deviceClass == nil)
    }

    @Test func attributesAreHumanizedAndSortedByName() throws {
        let entity = try makeEntity(attributes: [
            "state_class": "measurement",
            "battery_level": 87,
        ])
        let details = WatchEntityDetails(entity: entity)

        #expect(details.attributes.map(\.name) == ["Battery level", "State class"])
        #expect(details.attributes.map(\.id) == ["battery_level", "state_class"])
        #expect(details.attributes.map(\.value) == ["87", "measurement"])
    }

    @Test func attributesRenderedElsewhereAreHidden() throws {
        let entity = try makeEntity(attributes: [
            "friendly_name": "Living room temperature",
            "icon": "mdi:thermometer",
            "entity_picture": "/api/image/x.png",
            "unit_of_measurement": "°C",
            "device_class": "temperature",
            "supported_features": 15,
            "state_class": "measurement",
        ])
        let details = WatchEntityDetails(entity: entity)

        #expect(details.attributes.map(\.id) == ["state_class"])
    }

    @Test func emptyAndNullValuesAreDropped() throws {
        let entity = try makeEntity(attributes: [
            "empty_text": "   ",
            "nothing": NSNull(),
            "empty_list": [Any](),
            "kept": "value",
        ])
        let details = WatchEntityDetails(entity: entity)

        #expect(details.attributes.map(\.id) == ["kept"])
    }

    @Test func booleansReadAsYesNoWhileNumbersStayNumeric() throws {
        let entity = try makeEntity(attributes: [
            "is_charging": true,
            "is_full": false,
            // Numeric 1/0 also bridge to Bool in Swift, so these must not read as "Yes"/"No".
            "count": 1,
            "offset": 0,
            "precision": 21.5,
        ])
        let details = WatchEntityDetails(entity: entity)

        let values = Dictionary(uniqueKeysWithValues: details.attributes.map { ($0.id, $0.value) })
        #expect(values["is_charging"] == L10n.yesLabel)
        #expect(values["is_full"] == L10n.noLabel)
        #expect(values["count"] == "1")
        #expect(values["offset"] == "0")
        #expect(values["precision"] == "21.5")
    }

    @Test func collectionsAreFlattenedToOneLine() throws {
        let entity = try makeEntity(attributes: [
            "options": ["low", "high"],
            "thresholds": ["min_value": 1, "max_value": 9],
        ])
        let details = WatchEntityDetails(entity: entity)

        let values = Dictionary(uniqueKeysWithValues: details.attributes.map { ($0.id, $0.value) })
        #expect(values["options"] == "low, high")
        #expect(values["thresholds"] == "Max value: 9, Min value: 1")
    }
}
