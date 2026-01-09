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

    func status(for server: Server) -> NotificationManagerLocalPushStatus {
        if managers[server.identifier, default: []].contains(where: \.isActive) {
            if let state = syncStates[server].value {
                // manager is running and we have a value synced
                return .allowed(state)
            } else {
                // manager claims to be running but push provider didn't set sync status
                return .disabled
            }
        } else {
            // manager isn't running
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

    private func updateManagers() {
        Current.Log.info()

        NEAppPushManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self else { return }

            if let error {
                Current.Log.error("failed to load local push managers: \(error)")
                return
            }

            let encoder = JSONEncoder()

            var updatedManagers = [ConfigureManager]()
            var usedManagers = Set<NEAppPushManager>()
            var hasDirtyManagers = false

            // update or create managers for the servers we have
            for (ssid, servers) in serversBySSID() {
                Current.Log.info("configuring push for \(ssid): \(servers)")

                let existing = managers?.first(where: { $0.matchSSIDs == [ssid] })
                if let existing {
                    usedManagers.insert(existing)
                }
                let updated = updateManager(
                    existingManager: existing,
                    ssid: ssid,
                    servers: servers,
                    encoder: encoder
                )
                updatedManagers.append(updated)
                if updated.isDirty {
                    hasDirtyManagers = true
                }
            }

            // remove any existing managers that didn't match
            for manager in managers ?? [] where !usedManagers.contains(manager) {
                manager.removeFromPreferences { error in
                    Current.Log.info("remove unused manager \(manager) result: \(String(describing: error))")
                }
            }

            configure(managers: updatedManagers)

            // If we made changes to managers, reload them after a brief delay to ensure
            // the system picks up the changes, especially when enabling local push
            // while already on the internal network
            if hasDirtyManagers {
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.managerReloadDelay) { [weak self] in
                    self?.reloadManagersAfterSave()
                }
            }
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

        NEAppPushManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self else { return }

            if let error {
                Current.Log.error("failed to reload local push managers: \(error)")
                return
            }

            var configureManagers = [ConfigureManager]()

            // Only configure managers for currently enabled servers with configured SSIDs
            for (ssid, servers) in serversBySSID() {
                if let manager = managers?.first(where: { $0.matchSSIDs == [ssid] }) {
                    configureManagers.append(
                        ConfigureManager(ssid: ssid, manager: manager, servers: servers, isDirty: false)
                    )
                }
            }

            configure(managers: configureManagers)
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
        tokens.removeAll()

        managers = configureManagers.reduce(into: [Identifier<Server>: [NEAppPushManager]]()) { result, value in
            // notify on active state changes
            tokens.append(value.manager.observe(\.isActive) { [weak self, servers = value.servers] manager, _ in
                Current.Log.info("manager \(value.ssid) is active: \(manager.isActive)")
                self?.notifyObservers(for: servers)
            })

            for server in value.servers {
                result[server.identifier, default: []].append(value.manager)
            }

            value.manager.delegate = self
        }

        Current.Log.verbose("computed managers: \(managers)")

        notifyObservers()
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
        Current.servers.all.reduce(into: [String: [Server]]()) { result, server in
            let connection = server.info.connection

            guard connection.isLocalPushEnabled, connection.address(for: .internal) != nil else {
                return
            }

            for ssid in server.info.connection.internalSSIDs ?? [] {
                result[ssid, default: []].append(server)
            }
        }
    }
}

extension NotificationManagerLocalPushInterfaceExtension: ServerObserver {
    func serversDidChange(_ serverManager: ServerManager) {
        updateManagers()
    }
}

extension NotificationManagerLocalPushInterfaceExtension {
    func reconnectAll() {
        // Network Extension handles reconnection automatically
        Current.Log.info("reconnectAll called - reloading managers")
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
