import Foundation
import ObjectMapper
@testable import Shared
import Testing

@Suite("Sensor entity categories")
struct SensorEntityCategoryTests {
    private static let diagnosticSensorIDs: Set<WebhookSensorId> = [
        .appVersion,
        .connectivityBSID,
        .connectivitySSID,
        .connectivityConnectionType,
        .lastUpdateTrigger,
        .locationPermission,
        .storage,
        .watchBattery,
        .watchBatteryState,
    ]

    @Test("Home Assistant's own spellings")
    func rawValuesMatchHomeAssistant() {
        #expect(SensorEntityCategory.allCases.map(\.rawValue).sorted() == ["config", "diagnostic"])
    }

    @Test("Every sensor the app names falls on the side it was put")
    func knownSensorsAreClassified() {
        for sensorID in WebhookSensorId.allCases {
            let category = SensorEntityCategory.category(forSensorUniqueID: sensorID.rawValue)
            let expected: SensorEntityCategory? = Self.diagnosticSensorIDs.contains(sensorID) ? .diagnostic : nil
            #expect(category == expected, "\(sensorID.rawValue) should be \(String(describing: expected))")
        }
    }

    @Test("What the device reports about itself is a diagnostic")
    func deviceStateSensorsAreDiagnostic() {
        #expect(SensorEntityCategory.category(forSensorUniqueID: "storage") == .diagnostic)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "connectivity_ssid") == .diagnostic)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "connectivity_bssid") == .diagnostic)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "connectivity_connection_type") == .diagnostic)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "app-version") == .diagnostic)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "last_update_trigger") == .diagnostic)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "location-permission") == .diagnostic)
    }

    @Test("What the device measures around it stays a plain sensor")
    func measurementsAreNotDiagnostic() {
        #expect(SensorEntityCategory.category(forSensorUniqueID: "activity") == nil)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "geocoded_location") == nil)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "pressure") == nil)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "cameraMotion") == nil)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "cameraStream") == nil)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "iphone-audio-output") == nil)
    }

    @Test("Nothing a Mac alone reports is a diagnostic")
    func macOnlySensorsAreNotDiagnostic() {
        #expect(SensorEntityCategory.category(forSensorUniqueID: "active") == nil)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "displays_count") == nil)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "primary_display_name") == nil)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "primary_display_id") == nil)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "frontmost_app") == nil)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "camera_in_use") == nil)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "active_camera") == nil)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "microphone_in_use") == nil)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "active_microphone") == nil)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "audio_output_in_use") == nil)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "active_audio_output") == nil)
    }

    @Test("Apple Health and the pedometer are readings about a person, not about a device")
    func personalReadingsAreNotDiagnostic() {
        for uniqueID in PedometerSensor.allSensorIDs {
            #expect(SensorEntityCategory.category(forSensorUniqueID: uniqueID) == nil, "\(uniqueID)")
        }
        #expect(SensorEntityCategory.category(forSensorUniqueID: "health_steps") == nil)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "health_heart_rate") == nil)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "health_sleep_duration") == nil)
    }

    @Test("The kiosk is what a wall tablet's dashboard shows, all of it")
    func kioskSensorsAreNotDiagnostic() {
        #expect(SensorEntityCategory.category(forSensorUniqueID: "kioskMode") == nil)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "kioskBrightness") == nil)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "kioskVolume") == nil)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "kioskScreensaver") == nil)
    }

    @Test("Focus is something automations act on, not a diagnostic")
    func focusSensorsAreNotDiagnostic() {
        #expect(SensorEntityCategory.category(forSensorUniqueID: "focus") == nil)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "focus_name") == nil)
    }

    @Test("A battery is a diagnostic whatever the hardware calls it")
    func batterySensorsAreDiagnostic() {
        let anonymous = DeviceBattery(level: 50, state: .unplugged, attributes: [:])
        let anonymousSensors = BatterySensor.sensors(battery: anonymous)
        #expect(anonymousSensors.compactMap(\.UniqueID) == ["battery_level", "battery_state"])
        #expect(anonymousSensors.allSatisfy { $0.entityCategory == .diagnostic })

        var named = anonymous
        named.name = "Internal Battery"
        named.uniqueID = "C02X1234J1WK"
        let namedSensors = BatterySensor.sensors(battery: named)
        #expect(namedSensors.compactMap(\.UniqueID) == ["C02X1234J1WK_level", "C02X1234J1WK_state"])
        #expect(namedSensors.allSatisfy { $0.entityCategory == .diagnostic })
    }

    @Test("A SIM is a diagnostic however many the device has")
    func simSensorsAreDiagnostic() {
        #expect(SensorEntityCategory.category(forSensorUniqueID: "connectivity_sim_1") == .diagnostic)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "connectivity_sim_2") == .diagnostic)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "connectivity_sim_?") == .diagnostic)
    }

    @Test("An ID the app doesn't know is left uncategorised")
    func unknownSensorsAreNotCategorised() {
        #expect(SensorEntityCategory.category(forSensorUniqueID: "") == nil)
        #expect(SensorEntityCategory.category(forSensorUniqueID: "something_else_entirely") == nil)
    }

    @Test("Every way of building the same sensor describes it the same")
    func everyConstructionPathAgrees() {
        let uniqueID = WebhookSensorId.storage.rawValue

        let plain = WebhookSensor(name: "Storage", uniqueID: uniqueID)
        let withState = WebhookSensor(name: "Storage", uniqueID: uniqueID, state: "50", unit: "%")
        let withIcon = WebhookSensor(name: "Storage", uniqueID: uniqueID, icon: "mdi:database", state: "50")
        let withMaterialIcon = WebhookSensor(name: "Storage", uniqueID: uniqueID, icon: .databaseIcon, state: "50")
        let withDeviceClass = WebhookSensor(
            name: "Storage",
            uniqueID: uniqueID,
            icon: "mdi:database",
            deviceClass: .battery,
            state: "50"
        )
        let awaitingPermission = WebhookSensor(awaitingPermissionNamed: "Storage", uniqueID: uniqueID)
        let redacted = WebhookSensor(redacting: plain)

        let all = [plain, withState, withIcon, withMaterialIcon, withDeviceClass, awaitingPermission, redacted]
        #expect(all.allSatisfy { $0.entityCategory == .diagnostic })
    }

    @Test("A sensor that isn't a diagnostic never becomes one")
    func plainSensorsStayPlainAcrossConstructionPaths() {
        let uniqueID = WebhookSensorId.pressure.rawValue

        let plain = WebhookSensor(name: "Pressure", uniqueID: uniqueID)
        let awaitingPermission = WebhookSensor(awaitingPermissionNamed: "Pressure", uniqueID: uniqueID)
        let redacted = WebhookSensor(redacting: plain)

        #expect([plain, awaitingPermission, redacted].allSatisfy { $0.entityCategory == nil })
    }

    @Test("Registration carries the category")
    func registrationCarriesTheCategory() {
        let sensor = WebhookSensor(name: "Storage", uniqueID: WebhookSensorId.storage.rawValue)

        #expect(sensor.toJSON()["entity_category"] as? String == "diagnostic")
    }

    @Test("A state update carries nothing but the state")
    func updatesDoNotCarryTheCategory() {
        let sensor = WebhookSensor(name: "Storage", uniqueID: WebhookSensorId.storage.rawValue)

        let update = Mapper<WebhookSensor>(context: WebhookSensorContext(update: true)).toJSON(sensor)
        #expect(update["entity_category"] == nil)
    }

    @Test("A sensor with no category leaves the key out entirely")
    func uncategorisedSensorsSendNothing() {
        let sensor = WebhookSensor(name: "Activity", uniqueID: WebhookSensorId.activity.rawValue)

        #expect(sensor.toJSON()["entity_category"] == nil)
    }

    @Test("A redacted sensor still describes itself")
    func redactedSensorsStillCarryTheCategory() {
        let sensor = WebhookSensor(name: "Storage", uniqueID: WebhookSensorId.storage.rawValue, state: "50")

        let payload = WebhookSensor(redacting: sensor).toJSON()
        #expect(payload["entity_category"] as? String == "diagnostic")
        #expect(payload["state"] as? String == "unavailable")
    }
}
