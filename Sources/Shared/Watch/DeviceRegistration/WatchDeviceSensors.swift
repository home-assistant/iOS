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

    /// Current readings, in `all` order. A reading the watch can't take right now (WatchKit reports
    /// the level as -1 while battery monitoring is unavailable) is reported as `unavailable` rather
    /// than as the nonsense value it would otherwise turn into.
    public static func current() -> [WebhookSensor] {
        let ids = all.map(\.uniqueID)
        return Current.device.batteries()
            .flatMap { battery -> [WebhookSensor] in
                let sensors = BatterySensor.sensors(battery: battery)
                guard battery.level >= 0 else {
                    return sensors.map(WebhookSensor.init(redacting:))
                }
                return sensors
            }
            .filter { sensor in sensor.UniqueID.map { ids.contains($0) } ?? false }
            .sorted { lhs, rhs in
                (ids.firstIndex(of: lhs.UniqueID ?? "") ?? 0) < (ids.firstIndex(of: rhs.UniqueID ?? "") ?? 0)
            }
    }

    /// The `register_sensor` payload for one sensor, carrying whether the user switched it on so
    /// Home Assistant creates its entity enabled or disabled accordingly. A sensor that is off is
    /// registered redacted, as the phone does: registering is not a way to send its value.
    public static func registrationPayload(sensor: WebhookSensor, enabled: Bool) -> [String: Any] {
        let outgoing = enabled ? sensor : WebhookSensor(redacting: sensor)
        outgoing.Disabled = !enabled
        return outgoing.toJSON()
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
        failures(in: response).compactMap { uniqueID, failure in
            failure.ErrorCode == "not_registered" ? uniqueID : nil
        }.sorted()
    }

    /// What a `update_sensor_states` response rejected, by unique ID, other than sensors that just
    /// need registering. Home Assistant answers per sensor inside an otherwise successful response,
    /// so a rejected value only shows up here.
    public static func rejections(in response: Any) -> [String: String] {
        failures(in: response).reduce(into: [:]) { rejections, entry in
            guard entry.value.ErrorCode != "not_registered" else { return }
            rejections[entry.key] = entry.value.ErrorMessage ?? entry.value.ErrorCode ?? "rejected"
        }
    }

    private static func failures(in response: Any) -> [String: WebhookSensorResponse] {
        guard let dictionary = response as? [String: [String: Any]] else { return [:] }
        return dictionary.reduce(into: [:]) { failures, entry in
            guard let sensorResponse = WebhookSensorResponse(JSON: entry.value),
                  sensorResponse.Success == false else { return }
            failures[entry.key] = sensorResponse
        }
    }
}
