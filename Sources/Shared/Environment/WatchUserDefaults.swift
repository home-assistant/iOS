import Foundation

public enum WatchUserDefaultsKey: String {
    /// When the watch last received the server configuration from the paired iPhone.
    case serversUpdatedAt
    /// Where the watch runs actions (magic items): automatically, always via iPhone, or directly.
    case performActionTarget
    /// Last selected Assist pipeline display name for the Watch settings summary.
    case assistPipelineName
    /// `WatchConfig.lastModified` of the config the watch and iPhone last agreed on — the baseline for
    /// offline-edit conflict detection.
    case lastConfigSyncModified
    /// Opaque per-table digests the phone issued with the last applied database mirror; echoed on
    /// the next sync request so the phone can omit unchanged tables (delta sync).
    case databaseMirrorDigests
    /// Developer option: shows the "Perform action using" route picker in the watch settings.
    case allowChoosingMagicItemRoute
    /// Developer option: presents a live step-by-step log screen while a magic item executes.
    case verboseItemExecution
    /// Server ids from the last direct sync that had no URL considered safe/reachable on the watch.
    case directSyncNoReachableURLServerIds
}

/// Where the Apple Watch performs actions such as executing magic items.
public enum WatchActionTarget: String, CaseIterable {
    /// Connect directly from the Watch when it can reach Home Assistant, otherwise relay via the iPhone.
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

    // MARK: - Action target

    public var performActionTarget: WatchActionTarget {
        get { string(for: .performActionTarget).flatMap(WatchActionTarget.init(rawValue:)) ?? .auto }
        set { set(newValue.rawValue, key: .performActionTarget) }
    }

    /// The route actually used to execute magic items. Locked to `.auto` unless the developer
    /// "Allow choosing route" option is on, so a preference stored before the picker was hidden
    /// can't keep silently forcing a route.
    public var effectivePerformActionTarget: WatchActionTarget {
        allowChoosingMagicItemRoute ? performActionTarget : .auto
    }

    // MARK: - Developer options

    /// Developer option gating the "Perform action using" picker in the watch settings.
    public var allowChoosingMagicItemRoute: Bool {
        get { userDefaults.bool(forKey: WatchUserDefaultsKey.allowChoosingMagicItemRoute.rawValue) }
        set { userDefaults.set(newValue, forKey: WatchUserDefaultsKey.allowChoosingMagicItemRoute.rawValue) }
    }

    /// Developer option: present a live step-by-step log screen while a magic item executes.
    public var verboseItemExecution: Bool {
        get { userDefaults.bool(forKey: WatchUserDefaultsKey.verboseItemExecution.rawValue) }
        set { userDefaults.set(newValue, forKey: WatchUserDefaultsKey.verboseItemExecution.rawValue) }
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
