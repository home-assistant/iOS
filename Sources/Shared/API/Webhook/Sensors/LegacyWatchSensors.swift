import Foundation

public enum LegacyWatchSensors {
    private static let inFlightLock = NSLock()
    private static var inFlight = Set<String>()

    public static func needsRetiring(reportedBy config: ConfigResponse, on server: Server) -> Bool {
        config.entities != nil
            && isPersisted(server)
            && !hasRetired(for: server.identifier)
            && !isInFlight(server.identifier)
    }

    public static func retire(reportedBy config: ConfigResponse, on server: Server) async {
        guard let entities = config.entities, isPersisted(server), claim(server.identifier) else { return }
        defer { release(server.identifier) }

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

    private static func isPersisted(_ server: Server) -> Bool {
        Current.servers.server(for: server.identifier) != nil
    }

    private static func claim(_ serverIdentifier: Identifier<Server>) -> Bool {
        inFlightLock.lock()
        defer { inFlightLock.unlock() }
        guard !hasRetired(for: serverIdentifier), !inFlight.contains(serverIdentifier.rawValue) else { return false }
        inFlight.insert(serverIdentifier.rawValue)
        return true
    }

    private static func release(_ serverIdentifier: Identifier<Server>) {
        inFlightLock.lock()
        defer { inFlightLock.unlock() }
        inFlight.remove(serverIdentifier.rawValue)
    }

    private static func isInFlight(_ serverIdentifier: Identifier<Server>) -> Bool {
        inFlightLock.lock()
        defer { inFlightLock.unlock() }
        return inFlight.contains(serverIdentifier.rawValue)
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
