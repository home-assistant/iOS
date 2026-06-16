import Foundation

public enum WatchUserDefaultsKey: String {
    case watchSSID
    /// When the watch last received the server configuration from the paired iPhone.
    case serversUpdatedAt
}

public final class WatchUserDefaults {
    public static var shared = WatchUserDefaults()

    private let userDefaults = UserDefaults()

    public func set(_ value: Any?, key: WatchUserDefaultsKey) {
        userDefaults.set(value, forKey: key.rawValue)
    }

    public func string(for key: WatchUserDefaultsKey) -> String? {
        userDefaults.string(forKey: key.rawValue)
    }

    public func date(for key: WatchUserDefaultsKey) -> Date? {
        userDefaults.object(forKey: key.rawValue) as? Date
    }
}
