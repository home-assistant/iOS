import Foundation
import HAKit

/// Persists which sensors the user has enabled.
///
/// Enablement is an allowlist: a sensor reports to Home Assistant only while its unique ID is
/// present in `enabledSensors`. Anything the app has never been told to enable — including sensors
/// introduced by a later release — stays off until the user turns it on in settings.
///
/// Installs that predate the allowlist stored the inverse, a `disabledSensors` denylist, which the
/// first run after upgrading carries across. See `prepareIfNeeded()`.
public final class SensorEnablementStore {
    private enum Key {
        static let enabled = "enabledSensors"
        static let legacyDisabled = "disabledSensors"
        static let migrationState = "sensorEnablementMigrationState"
        static let upgradeDetected = "sensorEnablementUpgradeDetected"
        static let firstRunDefaultsApplied = "sensorFirstRunDefaultsApplied"

        static func legacyInitialDisable(_ uniqueID: String) -> String {
            "sensor_initially_disabled_\(uniqueID)"
        }
    }

    /// How far the denylist-to-allowlist migration has got. Absent means it hasn't started.
    private enum MigrationState: String {
        /// An existing install's selection has been carried across for every statically-known ID.
        /// Dynamic IDs — one per battery, SIM or audio device — still need picking up.
        case upgradeAwaitingDynamicIDs
        /// A first-time install has been seeded with the default selection, likewise still waiting
        /// on dynamic IDs.
        case freshInstallAwaitingDynamicIDs
        case complete
    }

    /// Serialises the one-time migration. The value is unused: the state being guarded lives in
    /// `prefs` rather than in memory, so every process sharing the app group sees the same result.
    private let migrationLock = HAProtected<Bool>(value: false)

    public init() {}

    private var prefs: UserDefaults {
        Current.settingsStore.prefs
    }

    // MARK: - Reading and writing

    public func isEnabled(uniqueID: String) -> Bool {
        prepareIfNeeded()
        return enabledSensorIDs.contains(uniqueID)
    }

    /// - Returns: whether the stored selection actually changed.
    @discardableResult
    public func setEnabled(_ value: Bool, forUniqueID uniqueID: String) -> Bool {
        prepareIfNeeded()

        var enabled = enabledSensorIDs
        let didChangeSelection = value ? enabled.insert(uniqueID).inserted : enabled.remove(uniqueID) != nil
        if didChangeSelection {
            enabledSensorIDs = enabled
        }

        let didRecordChoice = recordChoiceForPendingMigration(value, forUniqueID: uniqueID)
        return didChangeSelection || didRecordChoice
    }

    /// Mirrors an explicit choice into the legacy denylist while the migration is still waiting on
    /// dynamic IDs, because that pass reads the denylist to decide them. Without this, turning a
    /// per-battery or per-SIM sensor off before the app has produced it once would be undone.
    ///
    /// - Returns: whether the denylist changed.
    private func recordChoiceForPendingMigration(_ value: Bool, forUniqueID uniqueID: String) -> Bool {
        guard migrationState != .complete else { return false }

        var disabled = legacyDisabledSensorIDs
        let didChange = value ? disabled.remove(uniqueID) != nil : disabled.insert(uniqueID).inserted
        guard didChange else { return false }

        legacyDisabledSensorIDs = disabled
        return true
    }

    // MARK: - Migration

    /// Carries an existing install's sensor selection into the allowlist, once.
    ///
    /// An upgrade is assumed rather than detected, because nothing available at this point reliably
    /// separates one from a first-time install, and guessing wrong in the other direction would
    /// silently switch off every sensor the user relies on. A genuine first-time install corrects
    /// the assumption from onboarding, via `applyFirstRunDefaults()`.
    private func prepareIfNeeded() {
        migrationLock.mutate { _ in
            guard migrationState == nil else { return }

            // Only used to decide whether onboarding may still reset this install to the defaults;
            // what to enable is decided by the safe assumption above, not by this.
            prefs.set(hasEvidenceOfPriorInstall, forKey: Key.upgradeDetected)

            enabledSensorIDs = SensorRegistry.staticSensorIDs
                .subtracting(legacyDisabledSensorIDs)
                .filter { uniqueID in
                    guard SensorRegistry.optInSensorIDs.contains(uniqueID) else { return true }
                    // Opt-in sensors only reached the denylist on devices that actually produced
                    // them, so an absent marker means "never seen" rather than "the user enabled
                    // it", and enabling one here would turn the camera on behind their back.
                    return prefs.object(forKey: Key.legacyInitialDisable(uniqueID)) != nil
                }
            migrationState = .upgradeAwaitingDynamicIDs
        }
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

    /// Seeds a first-time install with the sensors that are on out of the box.
    ///
    /// Runs at most once per install, and never for an install that arrived here by upgrading, so
    /// setting a server up again later can't overwrite the user's choices.
    ///
    /// - Returns: whether the stored selection actually changed.
    @discardableResult
    public func applyFirstRunDefaults() -> Bool {
        prepareIfNeeded()
        guard !prefs.bool(forKey: Key.firstRunDefaultsApplied), !prefs.bool(forKey: Key.upgradeDetected) else {
            return false
        }
        prefs.set(true, forKey: Key.firstRunDefaultsApplied)

        enabledSensorIDs = enabledSensorIDs.filter(SensorRegistry.isEnabledByDefaultOnFirstRun(uniqueID:))
        // Reopened so the pass below still picks up this device's battery sensors, whose IDs
        // depend on the hardware.
        migrationState = .freshInstallAwaitingDynamicIDs
        return true
    }

    /// Applies the migration to sensors whose unique IDs only exist at runtime — one per battery,
    /// SIM or audio device — the first time the app produces them.
    ///
    /// - Parameter producedIDs: every ID from one complete sensor generation. A partial generation
    ///   would finish the migration having missed whatever it left out.
    func seedDynamicIDsIfNeeded(from producedIDs: Set<String>) {
        prepareIfNeeded()
        guard let state = migrationState else { return }

        let dynamicIDs = producedIDs.subtracting(SensorRegistry.staticSensorIDs)
        var enabled = enabledSensorIDs

        switch state {
        case .upgradeAwaitingDynamicIDs:
            enabled.formUnion(dynamicIDs.subtracting(legacyDisabledSensorIDs))
        case .freshInstallAwaitingDynamicIDs:
            enabled.formUnion(dynamicIDs.filter(SensorRegistry.isEnabledByDefaultOnFirstRun(uniqueID:)))
        case .complete:
            return
        }

        enabledSensorIDs = enabled
        migrationState = .complete
        removeLegacyKeys()
    }

    private func removeLegacyKeys() {
        prefs.removeObject(forKey: Key.legacyDisabled)
        for uniqueID in SensorRegistry.optInSensorIDs {
            prefs.removeObject(forKey: Key.legacyInitialDisable(uniqueID))
        }
    }

    // MARK: - Storage

    private var enabledSensorIDs: Set<String> {
        get {
            Set(prefs.object(forKey: Key.enabled) as? [String] ?? [])
        }
        set {
            prefs.set(newValue.sorted(), forKey: Key.enabled)
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
            Key.enabled,
            Key.legacyDisabled,
            Key.migrationState,
            Key.upgradeDetected,
            Key.firstRunDefaultsApplied,
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
}
