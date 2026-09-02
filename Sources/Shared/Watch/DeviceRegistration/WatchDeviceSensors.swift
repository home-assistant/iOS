import Foundation
import ObjectMapper

/// The sensors the watch reports about itself. Battery level and state for now.
///
/// They read exactly like the iPhone's own battery sensors (same IDs, names, icons and attributes)
/// because they describe the same thing about a different device: `sensor.<watch name>_battery_level`
/// next to `sensor.<phone name>_battery_level`.
public enum WatchDeviceSensors {
    /// A sensor the watch can report, as its settings list it before it has ever been read.
    public struct Descriptor: Equatable, Identifiable {
        public let uniqueID: String
        public let name: String

        public var id: String { uniqueID }
    }

    public static let batteryLevelID = "battery_level"
    public static let batteryStateID = "battery_state"

    public static let all: [Descriptor] = [
        Descriptor(uniqueID: batteryLevelID, name: "Battery Level"),
        Descriptor(uniqueID: batteryStateID, name: "Battery State"),
    ]

    /// Current readings, in `all` order.
    public static func current() -> [WebhookSensor] {
        let ids = all.map(\.uniqueID)
        return Current.device.batteries()
            .flatMap(BatterySensor.sensors(battery:))
            .filter { sensor in sensor.UniqueID.map { ids.contains($0) } ?? false }
            .sorted { lhs, rhs in
                (ids.firstIndex(of: lhs.UniqueID ?? "") ?? 0) < (ids.firstIndex(of: rhs.UniqueID ?? "") ?? 0)
            }
    }

    /// The `register_sensor` payload for one sensor, carrying whether the user switched it on so
    /// Home Assistant creates its entity enabled or disabled accordingly.
    public static func registrationPayload(sensor: WebhookSensor, enabled: Bool) -> [String: Any] {
        sensor.Disabled = !enabled
        return sensor.toJSON()
    }

    /// The `update_sensor_states` payload: real readings for the sensors switched on, `unavailable`
    /// for the rest — the same redaction the phone applies, so a sensor switched off never leaks a
    /// value through a state update.
    public static func updatePayload(sensors: [WebhookSensor], enabledIDs: Set<String>) -> [[String: Any]] {
        let mapper = Mapper<WebhookSensor>(
            context: WebhookSensorContext(update: true),
            shouldIncludeNilValues: false
        )
        let outgoing = sensors.map { sensor -> WebhookSensor in
            guard let uniqueID = sensor.UniqueID, enabledIDs.contains(uniqueID) else {
                return WebhookSensor(redacting: sensor)
            }
            return sensor
        }
        return mapper.toJSONArray(outgoing)
    }

    /// The unique IDs a `update_sensor_states` response says Home Assistant doesn't know, which need
    /// registering before their state is accepted.
    public static func unregisteredIDs(in response: Any) -> [String] {
        guard let dictionary = response as? [String: [String: Any]] else { return [] }
        return dictionary.compactMap { uniqueID, json -> String? in
            guard let sensorResponse = WebhookSensorResponse(JSON: json),
                  sensorResponse.Success == false,
                  sensorResponse.ErrorCode == "not_registered" else {
                return nil
            }
            return uniqueID
        }.sorted()
    }
}
