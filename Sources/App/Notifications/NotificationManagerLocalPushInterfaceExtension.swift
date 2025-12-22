import Foundation
import HAKit
import NetworkExtension
import PromiseKit
import Shared

final class NotificationManagerLocalPushInterfaceExtension: NSObject, NotificationManagerLocalPushInterface {
    /// Delay in seconds before reloading managers after configuration changes.
    /// This allows the system to persist changes before attempting to reload them.
    private static let managerReloadDelay: TimeInterval = 0.5

    private var observers = [Observer]()
    private var syncStates: PerServerContainer<LocalPushStateSync>!
    private var managers = [Identifier<Server>: [NEAppPushManager]]()

    private var tokens: [NSKeyValueObservation] = [] {
        didSet {
            for token in oldValue where !tokens.contains(where: { $0 === token }) {
                token.invalidate()
            }
        }
    }

    // Serial queue for thread-safe access to shared mutable state
    private let queue = DispatchQueue(label: "io.homeassistant.LocalPushInterface")

    // Reconnection timer properties
    // These properties must only be accessed on the main queue since Timer.scheduledTimer requires main thread
    private var reconnectionTimer: Timer?
    private var reconnectionAttempt = 0
    private let reconnectionDelays: [TimeInterval] = [5, 10, 30]

    // Track servers that have failed connections
    // Access to this property is synchronized via the queue
    private var disconnectedServers = Set<Identifier<Server>>()

    func status(for server: Server) -> NotificationManagerLocalPushStatus {
        Current.Log.verbose("Checking local push status for server \(server.identifier.rawValue)")

        if managers[server.identifier, default: []].contains(where: \.isActive) {
            Current.Log.verbose("Server \(server.identifier.rawValue) has active manager(s)")

            if let state = syncStates[server].value {
                Current.Log.verbose("Server \(server.identifier.rawValue) sync state: \(state)")

                // Track disconnected state for reconnection logic
                // Use queue to synchronize access to disconnectedServers
                queue.sync {
                    switch state {
                    case .unavailable:
                        if !disconnectedServers.contains(server.identifier) {
                            Current.Log.info("Server \(server.identifier.rawValue) local push became unavailable")
                            Current.Log
                                .verbose(
                                    "Adding server \(server.identifier.rawValue) to disconnected set. Current disconnected servers: \(disconnectedServers.map(\.rawValue))"
                                )
                            disconnectedServers.insert(server.identifier)
                            Current.Log
                                .verbose("Disconnected servers after insert: \(disconnectedServers.map(\.rawValue))")
                            DispatchQueue.main.async { [weak self] in
                                self?.scheduleReconnection()
                            }
                        } else {
                            Current.Log.verbose("Server \(server.identifier.rawValue) already in disconnected set")
                        }
                    case .available, .establishing:
                        if disconnectedServers.contains(server.identifier) {
                            Current.Log.info("Server \(server.identifier.rawValue) local push reconnected successfully")
                            Current.Log
                                .verbose(
                                    "Removing server \(server.identifier.rawValue) from disconnected set. Current disconnected servers: \(disconnectedServers.map(\.rawValue))"
                                )
                            disconnectedServers.remove(server.identifier)
                            Current.Log
                                .verbose("Disconnected servers after remove: \(disconnectedServers.map(\.rawValue))")
                            if disconnectedServers.isEmpty {
                                Current.Log.verbose("All servers reconnected, cancelling reconnection timer")
                                DispatchQueue.main.async { [weak self] in
                                    self?.cancelReconnection()
                                }
                            } else {
                                Current.Log
                                    .verbose(
                                        "Still have \(disconnectedServers.count) disconnected server(s), keeping timer active"
                                    )
                            }
                        } else {
                            Current.Log
                                .verbose(
                                    "Server \(server.identifier.rawValue) is connected and was not in disconnected set"
                                )
                        }
                    }
                }

                return .allowed(state)
            } else {
                // manager claims to be running but push provider didn't set sync status
                Current.Log.verbose("Server \(server.identifier.rawValue) manager active but no sync state available")
                return .disabled
            }
        } else {
            // manager isn't running
            Current.Log.verbose("Server \(server.identifier.rawValue) has no active managers")
            queue.sync {
                if disconnectedServers.contains(server.identifier) {
                    Current.Log
                        .verbose(
                            "Removing server \(server.identifier.rawValue) from disconnected set (manager not running)"
                        )
                    disconnectedServers.remove(server.identifier)
                }
            }
            return .disabled
        }
    }

    func addObserver(
        for server: Server,
        handler: @escaping (NotificationManagerLocalPushStatus) -> Void
    ) -> HACancellable {
        let observer = Observer(server: server, handler: handler)
        observers.append(observer)
        return HABlockCancellable { [weak self] in
            self?.observers.removeAll(where: { $0 == observer })
        }
    }

    private struct Observer: Equatable {
        var identifier = UUID()
        var server: Server
        var handler: (NotificationManagerLocalPushStatus) -> Void

        static func == (lhs: Observer, rhs: Observer) -> Bool {
            lhs.identifier == rhs.identifier
        }
    }

    private func notifyObservers(for servers: [Server] = Current.servers.all) {
        for observer in observers where servers.contains(observer.server) {
            let status = status(for: observer.server)
            observer.handler(status)
        }
    }

    override init() {
        super.init()
        self.syncStates = PerServerContainer<LocalPushStateSync>(constructor: { server in
            let sync = LocalPushStateSync(settingsKey: PushProviderConfiguration.defaultSettingsKey(for: server))
            let token = sync.observe { [weak self] _ in
                self?.notifyObservers(for: [server])
            }
            return .init(sync, destructor: { _, _ in token.cancel() })
        })
        Current.servers.add(observer: self)

        updateManagers()
    }

    deinit {
        Current.Log.verbose("NotificationManagerLocalPushInterfaceExtension deinit, cleaning up reconnection timer")
        // Cancel timer on main thread since Timer must be invalidated on the thread it was created
        DispatchQueue.main.async { [reconnectionTimer] in
            reconnectionTimer?.invalidate()
        }
    }

    // MARK: - Reconnection Logic

    /// Schedules a reconnection attempt with gradual backoff
    /// Must be called on the main thread
    private func scheduleReconnection() {
        dispatchPrecondition(condition: .onQueue(.main))

        Current.Log
            .verbose(
                "scheduleReconnection called. Current attempt: \(reconnectionAttempt), timer active: \(reconnectionTimer != nil)"
            )

        // Cancel any existing timer
        reconnectionTimer?.invalidate()

        // Determine the delay based on the current attempt
        let delayIndex = min(reconnectionAttempt, reconnectionDelays.count - 1)
        let delay = reconnectionDelays[delayIndex]

        // Get disconnected server count in a thread-safe way
        let serverInfo = queue.sync { () -> (count: Int, identifiers: [String]) in
            (disconnectedServers.count, disconnectedServers.map(\.rawValue))
        }

        Current.Log
            .info(
                "Scheduling local push reconnection attempt #\(reconnectionAttempt + 1) in \(delay) seconds for \(serverInfo.count) server(s)"
            )
        Current.Log.verbose("Disconnected servers: \(serverInfo.identifiers)")
        Current.Log.verbose("Using delay index \(delayIndex) from reconnectionDelays array")

        reconnectionTimer = Timer.scheduledTimer(
            withTimeInterval: delay,
            repeats: false
        ) { [weak self] timer in
            Current.Log.verbose("Reconnection timer fired: \(timer)")
            self?.attemptReconnection()
        }

        Current.Log.verbose("Timer scheduled successfully with interval \(delay)s")
    }

    /// Attempts to reconnect by reloading managers
    /// Must be called on the main thread
    private func attemptReconnection() {
        dispatchPrecondition(condition: .onQueue(.main))

        reconnectionAttempt += 1

        // Get disconnected server info in a thread-safe way
        let serverInfo = queue.sync { () -> (count: Int, identifiers: [String]) in
            (disconnectedServers.count, disconnectedServers.map(\.rawValue))
        }

        Current.Log
            .info(
                "Attempting local push reconnection #\(reconnectionAttempt) for servers: \(serverInfo.identifiers)"
            )
        Current.Log.verbose("Current disconnected server count: \(serverInfo.count)")
        Current.Log
            .verbose(
                "Next delay will be: \(reconnectionDelays[min(reconnectionAttempt, reconnectionDelays.count - 1)])s"
            )

        // Trigger a reload of all managers to attempt reconnection
        Current.Log.verbose("Calling reloadManagersAfterSave() to attempt reconnection")
        reloadManagersAfterSave()

        Current.Log.verbose("reloadManagersAfterSave() called, waiting for state change to determine next action")
        // If still unavailable after this attempt, schedule the next one
        // This will be triggered by the state didSet when the connection fails
    }

    /// Cancels any pending reconnection timer and resets the attempt counter
    /// Must be called on the main thread
    private func cancelReconnection() {
        dispatchPrecondition(condition: .onQueue(.main))

        Current.Log
            .verbose(
                "cancelReconnection called. Timer active: \(reconnectionTimer != nil), attempt count: \(reconnectionAttempt)"
            )

        reconnectionTimer?.invalidate()
        reconnectionTimer = nil

        if reconnectionAttempt > 0 {
            Current.Log.info("Cancelling local push reconnection timer, all servers connected")
            Current.Log.verbose("Resetting reconnection attempt counter from \(reconnectionAttempt) to 0")
            reconnectionAttempt = 0
        } else {
            Current.Log.verbose("No active reconnection attempts to cancel")
        }
    }

    private func updateManagers() {
        Current.Log.info("updateManagers called - loading NEAppPushManager preferences")

        // Get disconnected server info in a thread-safe way
        let disconnectedServerIds = queue.sync {
            disconnectedServers.map(\.rawValue)
        }

        Current.Log.verbose("Current disconnected servers: \(disconnectedServerIds)")
        Current.Log.verbose("Reconnection attempt count: \(reconnectionAttempt)")

        NEAppPushManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self else {
                Current.Log.verbose("Self is nil in loadAllFromPreferences callback")
                return
            }

            if let error {
                Current.Log.error("failed to load local push managers: \(error)")
                Current.Log.verbose("Error details: \(String(describing: error))")
                return
            }

            Current.Log.verbose("Loaded \(managers?.count ?? 0) existing manager(s) from preferences")

            let (updatedManagers, hasDirtyManagers) = processManagersForSSIDs(
                existingManagers: managers ?? [],
                serversBySSID: serversBySSID()
            )

            removeUnusedManagers(existingManagers: managers ?? [], usedManagers: updatedManagers.map(\.manager))

            configure(managers: updatedManagers)

            scheduleReloadIfNeeded(hasDirtyManagers: hasDirtyManagers)
        }
    }

    /// Reloads manager configurations from system preferences after they have been saved.
    /// This ensures the NetworkExtension framework picks up configuration changes,
    /// particularly when enabling local push while already on the internal network.
    ///
    /// Note: This only configures managers that were successfully saved by updateManagers().
    /// Managers for removed SSIDs or disabled servers are intentionally not recreated.
    private func reloadManagersAfterSave() {
        Current.Log.info("Reloading managers after configuration changes")

        // Get disconnected server info in a thread-safe way
        let disconnectedServerIds = queue.sync {
            disconnectedServers.map(\.rawValue)
        }

        Current.Log.verbose("Current disconnected servers: \(disconnectedServerIds)")

        NEAppPushManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self else {
                Current.Log.verbose("Self is nil in reloadManagersAfterSave callback")
                return
            }

            if let error {
                Current.Log.error("failed to reload local push managers: \(error)")
                Current.Log.verbose("Error details: \(String(describing: error))")
                return
            }

            Current.Log.verbose("Reloaded \(managers?.count ?? 0) manager(s) from preferences")

            var configureManagers = [ConfigureManager]()

            let serversBySSID = serversBySSID()
            Current.Log.verbose("Found \(serversBySSID.count) SSID(s) with enabled servers for reload")

            // Only configure managers for currently enabled servers with configured SSIDs
            for (ssid, servers) in serversBySSID {
                if let manager = managers?.first(where: { $0.matchSSIDs == [ssid] }) {
                    Current.Log.verbose("Found saved manager for SSID '\(ssid)' with \(servers.count) server(s)")
                    Current.Log.verbose("Manager isActive: \(manager.isActive), isEnabled: \(manager.isEnabled)")
                    configureManagers.append(
                        ConfigureManager(ssid: ssid, manager: manager, servers: servers, isDirty: false)
                    )
                } else {
                    Current.Log.verbose("No saved manager found for SSID '\(ssid)', skipping")
                }
            }

            Current.Log.verbose("Reloading \(configureManagers.count) manager(s)")
            configure(managers: configureManagers)
            Current.Log.verbose("Reload complete")
        }
    }

    struct ConfigureManager {
        var ssid: String
        var manager: NEAppPushManager
        var servers: [Server]

        /// Indicates whether the manager's configuration has been modified and saved to preferences.
        /// A "dirty" manager is one that had changes to its properties (isEnabled, matchSSIDs,
        /// providerConfiguration, etc.) and was saved via `saveToPreferences()`.
        /// This flag is used to trigger a reload of managers after saving, ensuring the
        /// NetworkExtension framework picks up the configuration changes immediately.
        var isDirty: Bool = false
    }

    private func configure(managers configureManagers: [ConfigureManager]) {
        Current.Log.verbose("configure called with \(configureManagers.count) manager(s)")

        tokens.removeAll()
        Current.Log.verbose("Cleared \(tokens.count) previous observation tokens")

        managers = configureManagers.reduce(into: [Identifier<Server>: [NEAppPushManager]]()) { result, value in
            Current.Log.verbose("Configuring manager for SSID '\(value.ssid)' with \(value.servers.count) server(s)")

            // notify on active state changes
            tokens.append(value.manager.observe(\.isActive) { [weak self, servers = value.servers] manager, _ in
                Current.Log.info("manager \(value.ssid) is active: \(manager.isActive)")
                Current.Log
                    .verbose(
                        "Active state changed for SSID '\(value.ssid)', notifying \(servers.count) server observer(s)"
                    )
                self?.notifyObservers(for: servers)
            })

            for server in value.servers {
                result[server.identifier, default: []].append(value.manager)
                Current.Log.verbose("Added manager for SSID '\(value.ssid)' to server \(server.identifier.rawValue)")
            }

            value.manager.delegate = self
        }

        Current.Log.verbose("computed managers: \(managers)")
        Current.Log.verbose("Total servers with managers: \(managers.keys.count)")
        Current.Log.verbose("Total observation tokens: \(tokens.count)")

        Current.Log.verbose("Notifying all observers of configuration change")
        notifyObservers()
        Current.Log.verbose("Observer notification complete")
    }

    private func updateManager(
        existingManager: NEAppPushManager?,
        ssid: String,
        servers: [Server],
        encoder: JSONEncoder
    ) -> ConfigureManager {
        let manager = existingManager ?? NEAppPushManager()
        // just toggling isEnabled doesn't seem to kill off the extension reliably, so we remove when unwanted

        // Track whether any configuration properties are modified.
        // "Dirty" means the manager's configuration differs from what's currently saved
        // and requires a call to saveToPreferences() to persist the changes.
        var isDirty = false

        func updateAndDirty<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<NEAppPushManager, T>, _ value: T) {
            if manager[keyPath: keyPath] != value {
                Current.Log.info(keyPath)
                manager[keyPath: keyPath] = value
                isDirty = true
            }
        }

        updateAndDirty(\.isEnabled, true)
        updateAndDirty(\.localizedDescription, "HomeAssistant for \(ssid)")
        updateAndDirty(\.providerBundleIdentifier, AppConstants.BundleID + ".PushProvider")
        updateAndDirty(\.matchSSIDs, [ssid])

        let configurations: [PushProviderConfiguration] = servers.map {
            .init(serverIdentifier: $0.identifier, settingsKey: PushProviderConfiguration.defaultSettingsKey(for: $0))
        }

        do {
            let existing = manager.providerConfiguration[PushProviderConfiguration.providerConfigurationKey] as? Data
            let new = try encoder.encode(configurations)

            if existing != new {
                isDirty = true
                manager.providerConfiguration = [
                    PushProviderConfiguration.providerConfigurationKey: new,
                ]
            }
        } catch {
            Current.Log.error("failed to create config for push: \(error)")
            manager.providerConfiguration = [:]
        }

        if isDirty {
            manager.saveToPreferences { error in
                Current.Log.info("manager \(manager) saved, error: \(String(describing: error))")
            }
        }

        return ConfigureManager(ssid: ssid, manager: manager, servers: servers, isDirty: isDirty)
    }

    private func serversBySSID() -> [String: [Server]] {
        Current.Log.verbose("serversBySSID called, processing \(Current.servers.all.count) server(s)")

        let result = Current.servers.all.reduce(into: [String: [Server]]()) { result, server in
            let connection = server.info.connection

            Current.Log
                .verbose(
                    "Checking server \(server.identifier.rawValue): localPushEnabled=\(connection.isLocalPushEnabled), hasInternalURL=\(connection.address(for: .internal) != nil)"
                )

            guard connection.isLocalPushEnabled, connection.address(for: .internal) != nil else {
                Current.Log
                    .verbose(
                        "Server \(server.identifier.rawValue) excluded: localPushEnabled=\(connection.isLocalPushEnabled), internalURL=\(connection.address(for: .internal)?.absoluteString ?? "nil")"
                    )
                return
            }

            let ssids = server.info.connection.internalSSIDs ?? []
            Current.Log.verbose("Server \(server.identifier.rawValue) has \(ssids.count) configured SSID(s): \(ssids)")

            for ssid in ssids {
                result[ssid, default: []].append(server)
                Current.Log.verbose("Added server \(server.identifier.rawValue) to SSID '\(ssid)'")
            }
        }

        Current.Log.verbose("serversBySSID result: \(result.count) SSID(s) total")
        for (ssid, servers) in result {
            Current.Log.verbose("SSID '\(ssid)': \(servers.count) server(s) - \(servers.map(\.identifier.rawValue))")
        }

        return result
    }
}

extension NotificationManagerLocalPushInterfaceExtension: ServerObserver {
    func serversDidChange(_ serverManager: ServerManager) {
        updateManagers()
    }
}

extension NotificationManagerLocalPushInterfaceExtension: NEAppPushDelegate {
    func appPushManager(
        _ manager: NEAppPushManager,
        didReceiveIncomingCallWithUserInfo userInfo: [AnyHashable: Any] = [:]
    ) {
        // we do not have calls
    }
}

// MARK: - Manager Processing Helpers

extension NotificationManagerLocalPushInterfaceExtension {
    /// Processes all SSIDs and creates or updates managers for each one
    /// - Parameters:
    ///   - existingManagers: Array of existing NEAppPushManager instances from preferences
    ///   - serversBySSID: Dictionary mapping SSIDs to their associated servers
    /// - Returns: Tuple of (configured managers, whether any managers were modified)
    private func processManagersForSSIDs(
        existingManagers: [NEAppPushManager],
        serversBySSID: [String: [Server]]
    ) -> (managers: [ConfigureManager], hasDirtyManagers: Bool) {
        Current.Log.verbose("Found \(serversBySSID.count) SSID(s) with enabled servers")

        let encoder = JSONEncoder()
        var updatedManagers = [ConfigureManager]()
        var hasDirtyManagers = false

        for (ssid, servers) in serversBySSID {
            Current.Log.info("configuring push for \(ssid): \(servers)")
            Current.Log
                .verbose(
                    "Processing SSID '\(ssid)' with \(servers.count) server(s): \(servers.map(\.identifier.rawValue))"
                )

            let existing = findExistingManager(in: existingManagers, for: ssid)

            let updated = updateManager(
                existingManager: existing,
                ssid: ssid,
                servers: servers,
                encoder: encoder
            )

            updatedManagers.append(updated)

            if updated.isDirty {
                Current.Log.verbose("Manager for SSID '\(ssid)' is dirty, will trigger reload")
                hasDirtyManagers = true
            } else {
                Current.Log.verbose("Manager for SSID '\(ssid)' is clean, no changes needed")
            }
        }

        Current.Log
            .verbose("Total managers after update: \(updatedManagers.count), dirty managers: \(hasDirtyManagers)")

        return (updatedManagers, hasDirtyManagers)
    }

    /// Finds an existing manager for a given SSID
    /// - Parameters:
    ///   - managers: Array of existing managers
    ///   - ssid: The SSID to search for
    /// - Returns: The matching manager if found, nil otherwise
    private func findExistingManager(
        in managers: [NEAppPushManager],
        for ssid: String
    ) -> NEAppPushManager? {
        let existing = managers.first(where: { $0.matchSSIDs == [ssid] })
        if let existing {
            Current.Log.verbose("Found existing manager for SSID '\(ssid)', reusing it")
        } else {
            Current.Log.verbose("No existing manager found for SSID '\(ssid)', will create new one")
        }
        return existing
    }

    /// Removes managers that are no longer needed
    /// - Parameters:
    ///   - existingManagers: All existing managers
    ///   - usedManagers: Managers that are still in use
    private func removeUnusedManagers(
        existingManagers: [NEAppPushManager],
        usedManagers: [NEAppPushManager]
    ) {
        let usedSet = Set(usedManagers)
        let unusedManagers = existingManagers.filter { !usedSet.contains($0) }

        Current.Log.verbose("Found \(unusedManagers.count) unused manager(s) to remove")

        for manager in unusedManagers {
            Current.Log.verbose("Removing unused manager: \(manager)")
            manager.removeFromPreferences { error in
                Current.Log.info("remove unused manager \(manager) result: \(String(describing: error))")
                if let error {
                    Current.Log.verbose("Error removing manager: \(error)")
                } else {
                    Current.Log.verbose("Manager removed successfully")
                }
            }
        }
    }

    /// Schedules a reload of managers if any were modified
    /// - Parameter hasDirtyManagers: Whether any managers were modified
    private func scheduleReloadIfNeeded(hasDirtyManagers: Bool) {
        if hasDirtyManagers {
            Current.Log.verbose("Dirty managers detected, scheduling reload after \(Self.managerReloadDelay)s delay")
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.managerReloadDelay) { [weak self] in
                Current.Log.verbose("Reload delay elapsed, calling reloadManagersAfterSave")
                self?.reloadManagersAfterSave()
            }
        } else {
            Current.Log.verbose("No dirty managers, skipping delayed reload")
        }
    }
}
