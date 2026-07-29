import Foundation

public enum WatchUserDefaultsKey: String {
    /// When the watch last received the server configuration from the paired iPhone.
    case serversUpdatedAt
    /// Last selected Assist pipeline display name for the Watch settings summary.
    case assistPipelineName
    /// `WatchConfig.lastModified` of the config the watch and iPhone last agreed on — the baseline for
    /// offline-edit conflict detection.
    case lastConfigSyncModified
    /// Opaque per-table digests the phone issued with the last applied database mirror; echoed on
    /// the next sync request so the phone can omit unchanged tables (delta sync).
    case databaseMirrorDigests
    /// Developer option: presents a live step-by-step log screen while a magic item executes.
    case verboseItemExecution
    /// Developer option: shows the iPhone-with-a-slash icon in the home header while the paired
    /// iPhone is unreachable. Off by default — the icon never shows unless a developer opts in.
    case showIPhoneUnreachableIcon
    /// Developer option: post a local notification when a complication reload (self fetch) starts
    /// and finishes, saying whether each complication succeeded and why it failed. Stored in the
    /// shared app group (unlike the other keys) so the watch widget extension's own self fetch can
    /// read it too.
    case complicationRefreshNotificationsEnabled
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

    // MARK: - Offline config sync baseline

    /// `WatchConfig.lastModified` of the last config the watch and iPhone agreed on. `nil` until the
    /// first successful sync.
    public var lastSyncedModified: Double? {
        get { userDefaults.object(forKey: WatchUserDefaultsKey.lastConfigSyncModified.rawValue) as? Double }
        set {
            if let newValue {
                userDefaults.set(newValue, forKey: WatchUserDefaultsKey.lastConfigSyncModified.rawValue)
            } else {
                userDefaults.removeObject(forKey: WatchUserDefaultsKey.lastConfigSyncModified.rawValue)
            }
        }
    }

    // MARK: - Database mirror digests (delta sync)

    /// Digest map issued by the phone with the last applied database mirror. Opaque to the watch —
    /// stored verbatim and echoed on the next sync request. `nil` until the first sync (the phone
    /// then sends the full snapshot).
    public var databaseMirrorDigests: [String: String]? {
        get { userDefaults.dictionary(forKey: WatchUserDefaultsKey.databaseMirrorDigests.rawValue)
            as? [String: String]
        }
        set {
            if let newValue {
                userDefaults.set(newValue, forKey: WatchUserDefaultsKey.databaseMirrorDigests.rawValue)
            } else {
                userDefaults.removeObject(forKey: WatchUserDefaultsKey.databaseMirrorDigests.rawValue)
            }
        }
    }

    // MARK: - Developer options

    /// Developer option: present a live step-by-step log screen while a magic item executes.
    public var verboseItemExecution: Bool {
        get { userDefaults.bool(forKey: WatchUserDefaultsKey.verboseItemExecution.rawValue) }
        set { userDefaults.set(newValue, forKey: WatchUserDefaultsKey.verboseItemExecution.rawValue) }
    }

    /// Developer option: show the iPhone-with-a-slash icon in the home header while the paired
    /// iPhone is unreachable. Defaults to false, so the icon never shows unless opted in.
    public var showIPhoneUnreachableIcon: Bool {
        get { userDefaults.bool(forKey: WatchUserDefaultsKey.showIPhoneUnreachableIcon.rawValue) }
        set { userDefaults.set(newValue, forKey: WatchUserDefaultsKey.showIPhoneUnreachableIcon.rawValue) }
    }

    /// Developer option: post a local notification when a complication reload (self fetch) starts
    /// and finishes, saying whether each complication succeeded and why it failed. Defaults to
    /// false. Lives in the shared app-group defaults — not the standard suite the other developer
    /// options use — because the watch widget extension also self-fetches (on its own WidgetKit
    /// budget) and must be able to read the flag.
    public var complicationRefreshNotificationsEnabled: Bool {
        get {
            UserDefaults(suiteName: AppConstants.AppGroupID)?
                .bool(forKey: WatchUserDefaultsKey.complicationRefreshNotificationsEnabled.rawValue) ?? false
        }
        set {
            UserDefaults(suiteName: AppConstants.AppGroupID)?
                .set(newValue, forKey: WatchUserDefaultsKey.complicationRefreshNotificationsEnabled.rawValue)
        }
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
