import Foundation

public enum LegacyWatchSensors {
    public static func needsRetiring(reportedBy config: ConfigResponse, on server: Server) -> Bool {
        !hasRetired(for: server.identifier) && config.entities != nil
    }

    public static func retire(reportedBy config: ConfigResponse, on server: Server) async {
        guard needsRetiring(reportedBy: config, on: server), let entities = config.entities else { return }

        let sensors = sensorsToDisable(among: entities)
        guard !sensors.isEmpty else {
            recordRetired(for: server.identifier)
            return
        }

        Current.Log.info("disabling legacy watch sensors \(sensors.map(\.UniqueID)) on \(server.identifier)")

        do {
            for sensor in sensors {
                try await Current.webhooks.send(
                    server: server,
                    request: .init(type: "register_sensor", data: sensor.toJSON())
                ).asyncValue()
            }
            recordRetired(for: server.identifier)
        } catch {
            Current.Log.error("failed to disable legacy watch sensors on \(server.identifier): \(error)")
        }
    }

    static func sensorsToDisable(among entities: [String: ConfigResponseEntity]) -> [WebhookSensor] {
        disabledSensors.filter { sensor in
            guard let uniqueID = sensor.UniqueID, let entity = entities[uniqueID] else { return false }
            return !entity.disabled
        }
    }

    private static var disabledSensors: [WebhookSensor] {
        let level = with(WebhookSensor(
            name: "Watch Battery Level",
            uniqueID: WebhookSensorId.watchBattery.rawValue,
            icon: "mdi:battery-unknown",
            deviceClass: .battery,
            state: "unavailable",
            unit: "%"
        )) {
            $0.Disabled = true
        }

        let state = with(WebhookSensor(
            name: "Watch Battery State",
            uniqueID: WebhookSensorId.watchBatteryState.rawValue,
            icon: "mdi:battery-unknown",
            state: "unavailable"
        )) {
            $0.Disabled = true
        }

        return [level, state]
    }

    static func hasRetired(for serverIdentifier: Identifier<Server>) -> Bool {
        prefs.bool(forKey: key(for: serverIdentifier))
    }

    static func recordRetired(for serverIdentifier: Identifier<Server>) {
        prefs.set(true, forKey: key(for: serverIdentifier))
    }

    static func forgetRetired(for serverIdentifier: Identifier<Server>) {
        prefs.removeObject(forKey: key(for: serverIdentifier))
    }

    static func key(for serverIdentifier: Identifier<Server>) -> String {
        "legacyWatchSensorsRetired_\(serverIdentifier.rawValue)"
    }

    private static var prefs: UserDefaults {
        Current.settingsStore.prefs
    }
}
