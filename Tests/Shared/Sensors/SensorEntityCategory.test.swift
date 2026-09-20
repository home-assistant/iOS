import Foundation
import ObjectMapper
@testable import Shared
import Testing

@Suite("Sensor entity categories")
struct SensorEntityCategoryTests {
    /// Spelled out rather than derived, so a sensor changing sides is a deliberate edit here too.
    private static let diagnosticSensorIDs: Set<WebhookSensorId> = [
        .active,
        .appVersion,
        .connectivityBSID,
        .connectivitySSID,
        .connectivityConnectionType,
        .displaysCount,
        .focus,
        .focusName,
        .kioskMode,
        .lastUpdateTrigger,
        .locationPermission,
        .primaryDisplayId,
        .primaryDisplayName,
        .storage,
        .watchBattery,
        .watchBatteryState,
    ]

    @Test("Every known sensor falls on the side it was put")
    func knownSensorsAreClassified() {
        for sensorID in WebhookSensorId.allCases {
            let category = SensorEntityCategory.category(forSensorUniqueID: sensorID.rawValue)
            let expected: SensorEntityCategory? = Self.diagnosticSensorIDs.contains(sensorID) ? .diagnostic : nil
            #expect(category == expected, "\(sensorID.rawValue) should be \(String(describing: expected))")
        }
    }

    @Test("The device's own readings are diagnostics, whatever their IDs turn out to be")
    func runtimeDeviceSensorsAreDiagnostic() {
        // One battery, or one per battery a Mac reports.
        #expect(SensorEntityCategory.category(forSensorUniqueID: "battery_level") == .diagnostic)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "battery_state") == .diagnostic)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "C02X1234J1WK_level") == .diagnostic)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "C02X1234J1WK_state") == .diagnostic)
        // One per SIM.
        #expect(SensorEntityCategory.category(forSensorUniqueID: "connectivity_sim_1") == .diagnostic)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "connectivity_sim_2") == .diagnostic)
    }

    @Test("What the device measures stays a plain sensor")
    func measurementsAreNotDiagnostic() {
        for uniqueID in ["camera_in_use", "active_camera", "microphone_in_use", "active_audio_output"] {
            #expect(SensorEntityCategory.category(forSensorUniqueID: uniqueID) == nil, uniqueID)
        }
        #expect(SensorEntityCategory.category(forSensorUniqueID: "pedometer_steps") == nil)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "health_steps") == nil)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "health_heart_rate") == nil)
    }

    @Test("An ID the app doesn't know is left uncategorised")
    func unknownSensorsAreNotCategorised() {
        #expect(SensorEntityCategory.category(forSensorUniqueID: "something_else_entirely") == nil)
    }

    @Test("Home Assistant's own spellings")
    func rawValuesMatchHomeAssistant() {
        #expect(SensorEntityCategory.allCases.map(\.rawValue).sorted() == ["config", "diagnostic"])
    }

    @Test("Every way of building a sensor describes it the same")
    func sensorsCarryTheirCategory() {
        let plain = WebhookSensor(name: "Storage", uniqueID: WebhookSensorId.storage.rawValue)
        #expect(plain.entityCategory == .diagnostic)

        let withState = WebhookSensor(
            name: "Storage",
            uniqueID: WebhookSensorId.storage.rawValue,
            icon: "mdi:database",
            state: "50"
        )
        #expect(withState.entityCategory == .diagnostic)

        let awaitingPermission = WebhookSensor(
            awaitingPermissionNamed: "Focus",
            uniqueID: WebhookSensorId.focus.rawValue,
            type: "binary_sensor"
        )
        #expect(awaitingPermission.entityCategory == .diagnostic)
        #expect(WebhookSensor(redacting: awaitingPermission).entityCategory == .diagnostic)

        let measurement = WebhookSensor(
            name: "Pressure",
            uniqueID: WebhookSensorId.pressure.rawValue,
            icon: "mdi:gauge",
            deviceClass: .pressure,
            state: 1000
        )
        #expect(measurement.entityCategory == nil)
    }

    @Test("Only registration carries the category")
    func onlyRegistrationCarriesTheCategory() {
        let sensor = WebhookSensor(name: "Storage", uniqueID: WebhookSensorId.storage.rawValue)

        #expect(sensor.toJSON()["entity_category"] as? String == "diagnostic")

        let update = Mapper<WebhookSensor>(context: WebhookSensorContext(update: true)).toJSON(sensor)
        #expect(update["entity_category"] == nil)
    }

    @Test("A sensor with no category leaves the key out entirely")
    func uncategorisedSensorsSendNothing() {
        let sensor = WebhookSensor(name: "Activity", uniqueID: WebhookSensorId.activity.rawValue)
        #expect(sensor.toJSON()["entity_category"] == nil)
    }
}
