import Foundation

public enum SensorRegistrationVersionStore {
    public static func needsRegistration(for serverIdentifier: Identifier<Server>) -> Bool {
        prefs.string(forKey: key(for: serverIdentifier)) != AppConstants.version
    }

    public static func recordRegistration(for serverIdentifier: Identifier<Server>) {
        prefs.set(AppConstants.version, forKey: key(for: serverIdentifier))
    }

    public static func forgetRegistration(for serverIdentifier: Identifier<Server>) {
        prefs.removeObject(forKey: key(for: serverIdentifier))
    }

    static func key(for serverIdentifier: Identifier<Server>) -> String {
        "sensorRegistrationAppVersion_\(serverIdentifier.rawValue)"
    }

    private static var prefs: UserDefaults {
        Current.settingsStore.prefs
    }
}
