import Foundation

/// Remembers, per server, the app version whose sensor descriptions that server has been told.
///
/// `register_sensor` is the only call that carries what a sensor *is* — its name, icon, device
/// class, unit of measurement and entity category. `update_sensor_states` carries the state and
/// nothing else, and Home Assistant applies the description to an entity it already has only when
/// the sensor is registered again. Without this, a release that corrects any of that would reach
/// installs set up after it and no others: the entities everyone else already has keep whatever
/// the version that first registered them said, indefinitely.
///
/// Mirrors the Android companion app, which re-registers every sensor when it notices its own
/// version changed. Only the app's version is tracked — the server's doesn't change what the app
/// has to say about its sensors.
public enum SensorRegistrationVersionStore {
    /// Whether this server still has to be told what the sensors of this version of the app look
    /// like. True for a server that has never been told, which is what carries the change to an
    /// install that upgraded into this.
    public static func needsRegistration(for serverIdentifier: Identifier<Server>) -> Bool {
        prefs.string(forKey: key(for: serverIdentifier)) != AppConstants.version
    }

    /// Records that every sensor has just been registered with this server. Only ever called for a
    /// complete pass: registering one sensor after its switch changed says nothing about the rest.
    public static func recordRegistration(for serverIdentifier: Identifier<Server>) {
        prefs.set(AppConstants.version, forKey: key(for: serverIdentifier))
    }

    /// Forgets what a server was told, so the next connection registers everything again.
    public static func forgetRegistration(for serverIdentifier: Identifier<Server>) {
        prefs.removeObject(forKey: key(for: serverIdentifier))
    }

    private static func key(for serverIdentifier: Identifier<Server>) -> String {
        "sensorRegistrationAppVersion_\(serverIdentifier.rawValue)"
    }

    private static var prefs: UserDefaults {
        Current.settingsStore.prefs
    }
}
