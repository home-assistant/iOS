import Foundation

public enum WatchUserDefaultsKey: String {
    case watchSSID
    /// When the watch last received the server configuration from the paired iPhone.
    case serversUpdatedAt
    /// Where the watch runs actions (magic items): automatically, always via iPhone, or directly.
    case performActionTarget
    /// Last selected Assist pipeline display name for the Watch settings summary.
    case assistPipelineName
}

/// Where the Apple Watch performs actions such as executing magic items.
public enum WatchActionTarget: String, CaseIterable {
    /// Use the iPhone when it's immediately reachable, otherwise connect directly from the Watch.
    case auto
    /// Always route through the paired iPhone.
    case iPhone
    /// Always connect directly from the Apple Watch.
    case appleWatch
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

    // MARK: - Action target

    public var performActionTarget: WatchActionTarget {
        get { string(for: .performActionTarget).flatMap(WatchActionTarget.init(rawValue:)) ?? .auto }
        set { set(newValue.rawValue, key: .performActionTarget) }
    }

    // MARK: - Per-server URL override (watch-local)

    // The watch's server configuration is overwritten on every sync, so a "force this URL" choice
    // can't live in `ConnectionInfo`. It's stored here per server and re-applied after each sync.
    // The value is a `ConnectionInfo.URLType` raw value, or absent for automatic selection.
    private func urlOverrideKey(forServerId serverId: String) -> String {
        "serverURLOverride.\(serverId)"
    }

    public func urlOverrideRawValue(forServerId serverId: String) -> Int? {
        userDefaults.object(forKey: urlOverrideKey(forServerId: serverId)) as? Int
    }

    public func setURLOverrideRawValue(_ rawValue: Int?, forServerId serverId: String) {
        let key = urlOverrideKey(forServerId: serverId)
        if let rawValue {
            userDefaults.set(rawValue, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }

    // MARK: - Assist pipeline display name

    public var assistPipelineName: String? {
        get { string(for: .assistPipelineName) }
        set { set(newValue, key: .assistPipelineName) }
    }
}
