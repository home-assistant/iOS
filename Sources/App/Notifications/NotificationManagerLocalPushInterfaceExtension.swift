import Foundation
import HAKit
import NetworkExtension
import PromiseKit
import Shared

@available(iOS 14, *)
final class NotificationManagerLocalPushInterfaceExtension: NSObject, NotificationManagerLocalPushInterface {
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
        syncStates = PerServerContainer<LocalPushStateSync>(constructor: { server in
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

        NEAppPushManager.loadAllFromPreferences { [self] managers, error in
            guard error == nil else {
                Current.Log.error("failed to load local push managers: \(error!)")
                return
            }

            let encoder = JSONEncoder()

            var updatedManagers = [ConfigureManager]()
            var usedManagers = Set<NEAppPushManager>()

            // update or create managers for the servers we have
            for (ssid, servers) in serversBySSID() {
                Current.Log.info("configuring push for \(ssid): \(servers)")

                let existing = managers?.first(where: { $0.matchSSIDs == [ssid] })
                if let existing = existing {
                    usedManagers.insert(existing)
                }
                updatedManagers.append(updateManager(
                    existingManager: existing,
                    ssid: ssid,
                    servers: servers,
                    encoder: encoder
                ))
            }

            // remove any existing managers that didn't match
            for manager in managers ?? [] where !usedManagers.contains(manager) {
                manager.removeFromPreferences { error in
                    Current.Log.info("remove unused manager \(manager) result: \(String(describing: error))")
                }
            }

            configure(managers: updatedManagers)
        }
    }

    struct ConfigureManager {
        var ssid: String
        var manager: NEAppPushManager
        var servers: [Server]
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
        updateAndDirty(\.providerBundleIdentifier, Constants.BundleID + ".PushProvider")
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

        return ConfigureManager(ssid: ssid, manager: manager, servers: servers)
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

@available(iOS 14, *)
extension NotificationManagerLocalPushInterfaceExtension: ServerObserver {
    func serversDidChange(_ serverManager: ServerManager) {
        updateManagers()
    }
}

@available(iOS 14, *)
extension NotificationManagerLocalPushInterfaceExtension: NEAppPushDelegate {
    func appPushManager(
        _ manager: NEAppPushManager,
        didReceiveIncomingCallWithUserInfo userInfo: [AnyHashable: Any] = [:]
    ) {
        // we do not have calls
    }
}
