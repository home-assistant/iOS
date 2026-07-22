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
    /// Developer option: the watch fetches its reference database directly from Home Assistant
    /// over websocket instead of relying on the iPhone mirror. Off by default: real watches block
    /// `URLSessionWebSocketTask` for ordinary apps (TN3135), so this only works in specific
    /// environments (e.g. the simulator).
    case directDatabaseSyncEnabled
    /// Server ids from the last direct sync that had no URL considered safe/reachable on the watch.
    case directSyncNoReachableURLServerIds
    /// EXPERIMENT: hold a playback audio session open during the direct sync, to test whether
    /// watchOS's audio-streaming exception unlocks the websocket on real hardware (TN3135).
    case directSyncAudioSessionProbeEnabled
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

    /// Developer option: fetch the watch's reference database directly over websocket instead of
    /// the iPhone mirror. Defaults to false — the phone-relayed mirror is the supported path on
    /// real hardware (TN3135 blocks websockets for ordinary watch apps).
    public var directDatabaseSyncEnabled: Bool {
        get { userDefaults.bool(forKey: WatchUserDefaultsKey.directDatabaseSyncEnabled.rawValue) }
        set { userDefaults.set(newValue, forKey: WatchUserDefaultsKey.directDatabaseSyncEnabled.rawValue) }
    }

    /// EXPERIMENT: hold a playback audio session open during the direct sync to test whether the
    /// audio-streaming exception unlocks the websocket on real hardware. Defaults to false.
    public var directSyncAudioSessionProbeEnabled: Bool {
        get { userDefaults.bool(forKey: WatchUserDefaultsKey.directSyncAudioSessionProbeEnabled.rawValue) }
        set { userDefaults.set(newValue, forKey: WatchUserDefaultsKey.directSyncAudioSessionProbeEnabled.rawValue) }
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

    // MARK: - Internal URL consent prompt

    // Whether the user answered "No" to the home screen's "use your internal URL through the
    // phone's connection?" prompt for a server. Stored so a decline is honored permanently
    // instead of re-asking on every sync; the settings URL override remains the way to opt in
    // later.
    private func internalURLPromptDeclinedKey(forServerId serverId: String) -> String {
        "internalURLPromptDeclined.\(serverId)"
    }

    public func internalURLPromptDeclined(forServerId serverId: String) -> Bool {
        userDefaults.bool(forKey: internalURLPromptDeclinedKey(forServerId: serverId))
    }

    public func setInternalURLPromptDeclined(_ declined: Bool, forServerId serverId: String) {
        userDefaults.set(declined, forKey: internalURLPromptDeclinedKey(forServerId: serverId))
    }

    public var directSyncNoReachableURLServerIds: Set<String> {
        get {
            Set(userDefaults.stringArray(forKey: WatchUserDefaultsKey.directSyncNoReachableURLServerIds.rawValue) ?? [])
        }
        set {
            userDefaults.set(Array(newValue), forKey: WatchUserDefaultsKey.directSyncNoReachableURLServerIds.rawValue)
        }
    }

    // MARK: - Assist pipeline display name

    public var assistPipelineName: String? {
        get { string(for: .assistPipelineName) }
        set { set(newValue, key: .assistPipelineName) }
    }
}
