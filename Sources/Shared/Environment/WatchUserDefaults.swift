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
    /// The one list of switched-on sensors every server shared before they were chosen per server.
    /// Only read by `WatchSensorEnablementStore`'s split, which removes it once it has been handed
    /// to each server.
    case enabledSensorIDs
    /// Unique IDs of the sensors the watch reports about itself that the user switched on, by
    /// server identifier.
    case enabledSensorIDsByServer
    /// Set once the shared list above has been handed to every server the watch had at the time,
    /// which is what keeps a server added later from inheriting it.
    case enabledSensorIDsSplitAcrossServers
    /// When the watch last sent its sensors successfully, to any server.
    case sensorReportLastSuccessAt
    /// What the last failed sensor report said, cleared by the next run that has no failure.
    case sensorReportLastError
}

public final class WatchUserDefaults: WatchSensorSettings {
    public static var shared = WatchUserDefaults()

    private let userDefaults: UserDefaults

    /// Which sensors each server receives. Every sensor is opt-in, so an ID that isn't in a server's
    /// list is off there and nothing about it is sent to that server.
    private let sensorEnablement: WatchSensorEnablementStore

    init() {
        let defaults = UserDefaults()
        self.userDefaults = defaults
        self.sensorEnablement = WatchSensorEnablementStore(defaults: defaults, servers: { Current.servers.all })
    }

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

    /// Adopt the phone's digests for the tables a payload actually carried, keeping the stored
    /// values for every other table.
    ///
    /// The phone issues its full current digest map with each payload, but a payload may omit
    /// tables — a delta sync, a delta push, or a table the phone declined to send. Adopting a
    /// digest for data the watch did not receive would claim it holds rows it does not, and the
    /// omission would then repeat on every future sync. Merging only the carried keys keeps the
    /// stored map an honest description of what is actually in the local database.
    public func mergeDatabaseMirrorDigests(_ digests: [String: String]?, carrying keys: Set<String>) {
        guard let digests, !keys.isEmpty else { return }
        var merged = databaseMirrorDigests ?? [:]
        for key in keys {
            // A carried table with no digest (an older phone, or a read the phone couldn't hash)
            // drops the stored entry so the table is requested again rather than assumed current.
            merged[key] = digests[key]
        }
        databaseMirrorDigests = merged
    }

    /// Digest map describing the mirrored tables currently in the local database. Opaque to the
    /// watch — the values come from the phone and are echoed on the next sync request. `nil` until
    /// the first sync (the phone then sends the full snapshot).
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

    // MARK: - Watch sensors (reported by the watch as a device of its own)

    public func enabledSensorIDs(forServer serverID: Identifier<Server>) -> Set<String> {
        sensorEnablement.enabledSensorIDs(forServer: serverID)
    }

    public func isSensorEnabled(uniqueID: String, forServer serverID: Identifier<Server>) -> Bool {
        sensorEnablement.isSensorEnabled(uniqueID: uniqueID, forServer: serverID)
    }

    public func setSensorEnabled(_ enabled: Bool, uniqueID: String, forServer serverID: Identifier<Server>) {
        sensorEnablement.setSensorEnabled(enabled, uniqueID: uniqueID, forServer: serverID)
    }

    /// Drops the sensor choices of every server other than `serverIDs`; called once a sync from the
    /// iPhone has settled which servers the watch has.
    public func forgetSensorEnablement(forServersOtherThan serverIDs: [Identifier<Server>]) {
        sensorEnablement.forgetServers(otherThan: serverIDs)
    }

    /// When the watch last sent its sensors successfully. `nil` until the first success.
    public var lastSensorReportAt: Date? {
        get { date(for: .sensorReportLastSuccessAt) }
        set { set(newValue, key: .sensorReportLastSuccessAt) }
    }

    /// What the most recent run's first failure said, or `nil` when it had none.
    public var lastSensorReportError: String? {
        get { string(for: .sensorReportLastError) }
        set { set(newValue, key: .sensorReportLastError) }
    }

    // MARK: - Assist pipeline display name

    public var assistPipelineName: String? {
        get { string(for: .assistPipelineName) }
        set { set(newValue, key: .assistPipelineName) }
    }
}
