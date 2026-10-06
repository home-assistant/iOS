import Foundation

/// Persists which sensors the user has enabled, for each server separately.
///
/// Enablement is an allowlist per server: a sensor reports to a Home Assistant only while its
/// unique ID is present in that server's list. Anything the app has never been told to enable for
/// a server — including sensors introduced by a later release, and every sensor of a server added
/// after this screen existed — stays off until the user turns it on for that server.
///
/// Two migrations feed the allowlists, and an install can arrive needing either or both:
///
/// 1. Installs that predate the allowlist stored the inverse, a `disabledSensors` denylist. See
///    `migrateLegacyDenylistIfNeeded()`.
/// 2. Installs that predate *this* screen stored one device-wide allowlist shared by every server.
///    See `splitAcrossServersIfNeeded()`, which copies that one selection to each server the
///    install already had, so nothing a user picked stops reporting where it used to.
public final class SensorEnablementStore {
    private enum Key {
        /// The per-server allowlists: server identifier to the unique IDs enabled for it.
        static let enabledByServer = "enabledSensorsByServer"
        /// The one device-wide allowlist that predates per-server enablement. Consumed by the
        /// split, and removed once every migration has finished.
        static let legacyEnabled = "enabledSensors"
        static let legacyDisabled = "disabledSensors"
        static let migrationState = "sensorEnablementMigrationState"
        static let upgradeDetected = "sensorEnablementUpgradeDetected"
        static let firstRunDefaultsApplied = "sensorFirstRunDefaultsApplied"
        /// The servers that inherited the device-wide selection. Present — even empty — once the
        /// split has run, which is what stops it running twice.
        static let inheritingServers = "sensorEnablementInheritingServers"

        static func legacyInitialDisable(_ uniqueID: String) -> String {
            "sensor_initially_disabled_\(uniqueID)"
        }
    }

    /// How far the denylist-to-allowlist migration has got. Absent means it hasn't started.
    private enum MigrationState: String {
        /// An existing install's selection has been carried across for every statically-known ID.
        /// Dynamic IDs — one per battery, SIM or audio device — still need picking up.
        case upgradeAwaitingDynamicIDs
        /// Written by the version that seeded a first-time install with default sensors. Kept so an
        /// install left mid-migration by it still decodes; nothing defaults on any more.
        case freshInstallAwaitingDynamicIDs
        case complete
    }

    /// Serialises the one-time migrations. The state they guard lives in `prefs` rather than in
    /// memory, so every process sharing the app group ends up with the same result.
    private let migrationLock = NSLock()

    public init() {}

    private var prefs: UserDefaults {
        Current.settingsStore.prefs
    }

    // MARK: - Reading and writing

    public func isEnabled(uniqueID: String, forServer serverID: Identifier<Server>) -> Bool {
        prepareIfNeeded()
        return enabledSensorIDsByServer[serverID.rawValue]?.contains(uniqueID) ?? false
    }

    /// One server's whole selection in a single read, for callers that would otherwise ask about
    /// many sensors in a row: every `isEnabled(uniqueID:forServer:)` re-reads the allowlists out of
    /// the app group defaults.
    public func enabledUniqueIDs(forServer serverID: Identifier<Server>) -> Set<String> {
        prepareIfNeeded()
        return enabledSensorIDsByServer[serverID.rawValue] ?? []
    }

    /// Whether any server this install still has is set to receive the sensor.
    ///
    /// This is the question device-level work asks — whether to observe the camera, read Apple
    /// Health, or keep a signaler running — because that work happens once for the device no
    /// matter how many servers the values end up going to.
    ///
    /// Servers that have been removed are ignored rather than pruned, so a stale allowlist left by
    /// one can't keep hardware awake for a server that is gone.
    public func isEnabledForAnyServer(uniqueID: String) -> Bool {
        prepareIfNeeded()
        let byServer = enabledSensorIDsByServer
        return Current.servers.all.contains { server in
            byServer[server.identifier.rawValue]?.contains(uniqueID) ?? false
        }
    }

    /// - Returns: whether the stored selection actually changed.
    @discardableResult
    public func setEnabled(
        _ value: Bool,
        forUniqueID uniqueID: String,
        forServer serverID: Identifier<Server>
    ) -> Bool {
        prepareIfNeeded()

        var byServer = enabledSensorIDsByServer
        var enabled = byServer[serverID.rawValue] ?? []
        let didChangeSelection = value ? enabled.insert(uniqueID).inserted : enabled.remove(uniqueID) != nil
        if didChangeSelection {
            byServer[serverID.rawValue] = enabled
            enabledSensorIDsByServer = byServer
        }

        let didRecordChoice = recordChoiceForPendingMigration(value, forUniqueID: uniqueID)
        return didChangeSelection || didRecordChoice
    }

    /// Mirrors an explicit choice into the legacy denylist while the migration is still waiting on
    /// dynamic IDs, because that pass reads the denylist to decide them. Without this, turning a
    /// per-battery or per-SIM sensor off before the app has produced it once would be undone.
    ///
    /// Only switching off is recorded. The denylist has no room for "off here, on there", and it is
    /// read as "give this to nobody", so an off is safe to mirror — the sensor has never been
    /// produced, and so is reporting to nobody yet — while an on is not: clearing the entry would
    /// let the dynamic pass hand the sensor to every inheriting server, when the user asked for it
    /// on one. Switching one on needs no mirror anyway, because that writes straight to the
    /// server's own allowlist and the dynamic pass only ever adds.
    ///
    /// - Returns: whether the denylist changed.
    private func recordChoiceForPendingMigration(_ value: Bool, forUniqueID uniqueID: String) -> Bool {
        guard migrationState != .complete, !value else { return false }

        var disabled = legacyDisabledSensorIDs
        guard disabled.insert(uniqueID).inserted else { return false }

        legacyDisabledSensorIDs = disabled
        return true
    }

    // MARK: - Migration

    private func prepareIfNeeded() {
        migrationLock.lock()
        defer { migrationLock.unlock() }

        prepareWhileLocked()
    }

    /// The migrations themselves, for callers already holding `migrationLock`.
    private func prepareWhileLocked() {
        migrateLegacyDenylistIfNeeded()
        splitAcrossServersIfNeeded()
    }

    /// Carries an existing install's sensor selection into the allowlist, once.
    ///
    /// An upgrade is assumed rather than detected, because nothing available at this point reliably
    /// separates one from a first-time install, and guessing wrong in the other direction would
    /// silently switch off every sensor the user relies on. A genuine first-time install corrects
    /// the assumption from onboarding, via `resetForFirstRun()`.
    private func migrateLegacyDenylistIfNeeded() {
        guard migrationState == nil else { return }

        // Only used to decide whether onboarding may still reset this install to the defaults;
        // what to enable is decided by the safe assumption above, not by this.
        prefs.set(hasEvidenceOfPriorInstall, forKey: Key.upgradeDetected)

        deviceWideEnabledSensorIDs = SensorRegistry.legacyEraSensorIDs
            .subtracting(legacyDisabledSensorIDs)
            .filter { uniqueID in
                guard SensorRegistry.optInSensorIDs.contains(uniqueID) else { return true }
                // Opt-in sensors only reached the denylist on devices that actually produced them,
                // so an absent marker means "never seen" rather than "the user enabled it", and
                // enabling one here would turn the camera on behind their back.
                return prefs.object(forKey: Key.legacyInitialDisable(uniqueID)) != nil
            }
        migrationState = .upgradeAwaitingDynamicIDs
    }

    /// Gives every server the install already has the one selection they used to share, once.
    ///
    /// Sensors were device-wide until this screen existed, so an upgrading user's servers were all
    /// receiving the same thing. Copying that selection to each of them is what keeps every entity
    /// they already have reporting; a server added afterwards inherits nothing and starts opt-in.
    ///
    /// Does nothing while the install has no servers — one still in onboarding, or a process that
    /// reached here before the keychain was readable — and is retried on the next read, so a
    /// selection is never split away to nobody and lost.
    private func splitAcrossServersIfNeeded() {
        guard prefs.object(forKey: Key.inheritingServers) == nil else { return }

        let serverIDs = Current.servers.all.map(\.identifier.rawValue)
        guard !serverIDs.isEmpty else { return }

        let inherited = deviceWideEnabledSensorIDs
        var byServer = enabledSensorIDsByServer
        for serverID in serverIDs {
            byServer[serverID] = inherited
        }
        enabledSensorIDsByServer = byServer
        inheritingServerIDs = serverIDs

        removeFullyMigratedKeys()
    }

    /// Whether this install carries sensor state written by a version that predates the allowlist.
    private var hasEvidenceOfPriorInstall: Bool {
        if prefs.object(forKey: Key.legacyDisabled) != nil {
            return true
        }
        return SensorRegistry.optInSensorIDs.contains { uniqueID in
            prefs.object(forKey: Key.legacyInitialDisable(uniqueID)) != nil
        }
    }

    /// Empties the selection the migrations assumed for a first-time install, which has no prior
    /// choices to carry across: every sensor is opt-in, so a new install reports nothing to any
    /// server until the user switches something on.
    ///
    /// Runs at most once per install, and never for an install that arrived here by upgrading, so
    /// setting a server up again later can't overwrite the user's choices.
    ///
    /// - Returns: whether the stored selection actually changed.
    @discardableResult
    public func resetForFirstRun() -> Bool {
        prepareIfNeeded()
        guard !prefs.bool(forKey: Key.firstRunDefaultsApplied), !prefs.bool(forKey: Key.upgradeDetected) else {
            return false
        }
        prefs.set(true, forKey: Key.firstRunDefaultsApplied)

        let didChangeSelection = !deviceWideEnabledSensorIDs.isEmpty
            || enabledSensorIDsByServer.values.contains { !$0.isEmpty }
        deviceWideEnabledSensorIDs = []
        enabledSensorIDsByServer = [:]
        migrationState = .complete
        removeLegacyKeys()
        removeFullyMigratedKeys()
        return didChangeSelection
    }

    /// Applies the migration to sensors whose unique IDs only exist at runtime — one per battery,
    /// SIM or audio device — the first time the app produces them.
    ///
    /// They go to the servers that inherited the device-wide selection, and only to those: a server
    /// added after the split never had these sensors reporting to it, so seeding it here would
    /// start sending something the user never asked that server for.
    ///
    /// - Parameter producedIDs: every ID from one complete sensor generation. A partial generation
    ///   would finish the migration having missed whatever it left out.
    func seedDynamicIDsIfNeeded(from producedIDs: Set<String>) {
        migrationLock.lock()
        defer { migrationLock.unlock() }

        prepareWhileLocked()

        guard let state = migrationState else { return }

        let dynamicIDs = producedIDs.subtracting(SensorRegistry.staticSensorIDs)

        switch state {
        case .upgradeAwaitingDynamicIDs:
            let inherited = dynamicIDs.subtracting(legacyDisabledSensorIDs)
            // Still recorded device-wide as well, because the split may not have run yet — an
            // install with no readable servers reaches this pass first and inherits from it later.
            deviceWideEnabledSensorIDs = deviceWideEnabledSensorIDs.union(inherited)

            var byServer = enabledSensorIDsByServer
            for serverID in inheritingServerIDs {
                byServer[serverID] = (byServer[serverID] ?? []).union(inherited)
            }
            enabledSensorIDsByServer = byServer
        case .freshInstallAwaitingDynamicIDs:
            // Nothing to seed: an install left in this state by the version that had first-run
            // defaults keeps the sensors those defaults switched on, and the rest are opt-in.
            break
        case .complete:
            return
        }

        migrationState = .complete
        removeLegacyKeys()
        removeFullyMigratedKeys()
    }

    /// Drops a removed server's allowlist, so the app stops carrying choices for a server the user
    /// no longer has. Re-adding that server registers it under a new identifier, which starts
    /// opt-in like any other new server.
    /// - Returns: the sensors the removed servers were receiving, which are the ones whose
    ///   device-level answer to `isEnabledForAnyServer(uniqueID:)` may just have changed.
    @discardableResult
    func forgetServers(withIdentifiers serverIDs: [Identifier<Server>]) -> Set<String> {
        guard !serverIDs.isEmpty else { return [] }
        prepareIfNeeded()

        let rawIDs = Set(serverIDs.map(\.rawValue))

        var byServer = enabledSensorIDsByServer
        var forgotten = Set<String>()
        for rawID in rawIDs {
            forgotten.formUnion(byServer[rawID] ?? [])
        }
        if !byServer.keys.filter(rawIDs.contains).isEmpty {
            byServer = byServer.filter { !rawIDs.contains($0.key) }
            enabledSensorIDsByServer = byServer
        }

        // Dropped from the inheriting list too, so a still-pending dynamic-ID pass doesn't write
        // the allowlist straight back for a server that is gone.
        let remainingInheriting = inheritingServerIDs.filter { !rawIDs.contains($0) }
        if remainingInheriting.count != inheritingServerIDs.count {
            inheritingServerIDs = remainingInheriting
        }

        return forgotten
    }

    private func removeLegacyKeys() {
        prefs.removeObject(forKey: Key.legacyDisabled)
        for uniqueID in SensorRegistry.optInSensorIDs {
            prefs.removeObject(forKey: Key.legacyInitialDisable(uniqueID))
        }
    }

    /// Drops the device-wide allowlist once both migrations have run and nothing reads it again.
    private func removeFullyMigratedKeys() {
        guard migrationState == .complete, prefs.object(forKey: Key.inheritingServers) != nil else { return }
        prefs.removeObject(forKey: Key.legacyEnabled)
    }

    // MARK: - Storage

    private var enabledSensorIDsByServer: [String: Set<String>] {
        get {
            let stored = prefs.object(forKey: Key.enabledByServer) as? [String: [String]] ?? [:]
            return stored.mapValues(Set.init)
        }
        set {
            prefs.set(newValue.mapValues { $0.sorted() }, forKey: Key.enabledByServer)
        }
    }

    /// The one allowlist every server shared before this screen existed. Only the split reads it.
    private var deviceWideEnabledSensorIDs: Set<String> {
        get {
            Set(prefs.object(forKey: Key.legacyEnabled) as? [String] ?? [])
        }
        set {
            prefs.set(newValue.sorted(), forKey: Key.legacyEnabled)
        }
    }

    private var inheritingServerIDs: [String] {
        get {
            prefs.object(forKey: Key.inheritingServers) as? [String] ?? []
        }
        set {
            prefs.set(newValue, forKey: Key.inheritingServers)
        }
    }

    private var legacyDisabledSensorIDs: Set<String> {
        get {
            Set(prefs.object(forKey: Key.legacyDisabled) as? [String] ?? [])
        }
        set {
            prefs.set(newValue.sorted(), forKey: Key.legacyDisabled)
        }
    }

    private var migrationState: MigrationState? {
        get {
            prefs.string(forKey: Key.migrationState).flatMap(MigrationState.init(rawValue:))
        }
        set {
            prefs.set(newValue?.rawValue, forKey: Key.migrationState)
        }
    }

    // MARK: - Fakes

    /// Puts sensor enablement back to how a clean install finds it.
    ///
    /// Every test target shares one set of app group defaults, so a test that leaves an allowlist
    /// or a half-finished migration behind changes what the next one sees.
    static func resetForTesting() {
        let keys = [
            Key.enabledByServer,
            Key.legacyEnabled,
            Key.legacyDisabled,
            Key.migrationState,
            Key.upgradeDetected,
            Key.firstRunDefaultsApplied,
            Key.inheritingServers,
        ] + SensorRegistry.optInSensorIDs.map(Key.legacyInitialDisable)

        for key in keys {
            Current.settingsStore.prefs.removeObject(forKey: key)
        }
    }

    /// Puts sensor enablement into the state an install that predates the allowlist would be in.
    ///
    /// - Parameter seenOptInSensorIDs: opt-in sensors this device had already produced at least
    ///   once, which is what separates "the user turned it on" from "never seen".
    static func seedLegacyStateForTesting(
        disabledSensorIDs: [String],
        seenOptInSensorIDs: [WebhookSensorId] = []
    ) {
        resetForTesting()
        Current.settingsStore.prefs.set(disabledSensorIDs, forKey: Key.legacyDisabled)
        for sensorId in seenOptInSensorIDs {
            Current.settingsStore.prefs.set(true, forKey: Key.legacyInitialDisable(sensorId.rawValue))
        }
    }

    /// Puts sensor enablement into the state an install that predates *per-server* enablement would
    /// be in: the denylist migration already done, and one device-wide allowlist left to split.
    static func seedDeviceWideAllowlistForTesting(enabledSensorIDs: [String]) {
        resetForTesting()
        let prefs = Current.settingsStore.prefs
        prefs.set(enabledSensorIDs.sorted(), forKey: Key.legacyEnabled)
        prefs.set(MigrationState.complete.rawValue, forKey: Key.migrationState)
        prefs.set(true, forKey: Key.upgradeDetected)
    }
}
