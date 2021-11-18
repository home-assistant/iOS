import Foundation
import HAKit
import NetworkExtension
import PromiseKit
import Shared

@available(iOS 14, *)
final class NotificationManagerLocalPushInterfaceExtension: NSObject, NotificationManagerLocalPushInterface,
    NEAppPushDelegate {
    func status(for server: Server) -> NotificationManagerLocalPushStatus {
        #warning("multiserver")
        if let manager = manager, manager.isActive, let value = stateSync.value {
            return .allowed(value)
        } else {
            return .disabled
        }
    }

    func addObserver(
        for server: Server,
        handler: @escaping (NotificationManagerLocalPushStatus) -> Void
    ) -> HACancellable {
        let identifier = UUID()
        observers.append((identifier: identifier, server: server, handler: handler))
        return HABlockCancellable { [weak self] in
            self?.observers.removeAll(where: { $0.identifier == identifier })
        }
    }

    private var observers =
        [(identifier: UUID, server: Server, handler: (NotificationManagerLocalPushStatus) -> Void)]()
    private func notifyObservers(for server: Server) {
        let status = status(for: server)
        for observer in observers where observer.server == server {
            observer.handler(status)
        }
    }

    static let settingsKey = "LocalPush:Main"
    private let stateSync = LocalPushStateSync(settingsKey: NotificationManagerLocalPushInterfaceExtension.settingsKey)

    private var tokens: [NSKeyValueObservation] = []
    private var manager: NEAppPushManager? {
        didSet {
            if manager !== oldValue {
                tokens.forEach { $0.invalidate() }
                if let manager = manager {
                    tokens = setupObservation(manager: manager)
                } else {
                    tokens = []
                }
                #warning("multiserver")
                notifyObservers(for: Current.servers.all.first!)
            }
        }
    }

    override init() {
        super.init()

        _ = stateSync.observe { [weak self] (_: LocalPushManager.State) in
            #warning("multiserver")
            self?.notifyObservers(for: Current.servers.all.first!)
        }

        // future multi-server: move this to container
        NEAppPushManager.loadAllFromPreferences { [self] managers, error in
            if let manager = managers?.first {
                configureManager(manager: manager)
            } else {
                if let error = error {
                    Current.Log.error("failed to load local push details: \(error)")
                }
                updateManager().cauterize()
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(connectionInfoDidChange(_:)),
            name: SettingsStore.connectionInfoDidChange,
            object: nil
        )
    }

    @objc private func connectionInfoDidChange(_ note: Notification) {
        updateManager().cauterize()
    }

    private func configureManager(manager: NEAppPushManager) {
        self.manager = manager
        manager.delegate = self
    }

    private func setupObservation(manager: NEAppPushManager) -> [NSKeyValueObservation] {
        [
            manager.observe(\.isActive) { [weak self] manager, _ in
                Current.Log.info("manager is active: \(manager.isActive)")
                #warning("multiserver")
                self?.notifyObservers(for: Current.servers.all.first!)
            },
        ]
    }

    private func updateManager() -> Promise<Void> {
        guard
            let connectionInfo = Current.settingsStore.connectionInfo,
            connectionInfo.internalSSIDs?.isEmpty == false,
            connectionInfo.address(for: .internal) != nil,
            connectionInfo.isLocalPushEnabled else {
            return Promise { seal in
                guard let manager = self.manager else {
                    Current.Log.info("no local push - no internal info or not enabled")
                    seal.fulfill(())
                    return
                }

                Current.Log.info("removing manager \(manager) due to no internal info or not enabled")
                manager.removeFromPreferences { error in
                    Current.Log.info("remove from preferences: \(String(describing: error))")
                    seal.resolve(error)
                }
                self.manager = nil
            }
        }

        let manager: NEAppPushManager

        if let currentManager = self.manager {
            manager = currentManager
        } else {
            manager = NEAppPushManager()
            configureManager(manager: manager)
        }

        // just toggling isEnabled doesn't seem to kill off the extension reliably
        manager.isEnabled = true

        manager.localizedDescription = "HomeAssistant"
        manager.providerBundleIdentifier = Constants.BundleID + ".PushProvider"
        manager.matchSSIDs = Current.settingsStore.connectionInfo?.internalSSIDs ?? []
        manager.providerConfiguration = [
            LocalPushStateSync.settingsKey: Self.settingsKey,
        ]

        return Promise { seal in
            manager.saveToPreferences { error in
                Current.Log.info("manager \(manager) updated, error: \(String(describing: error))")
                seal.resolve(error)
            }
        }
    }

    func appPushManager(
        _ manager: NEAppPushManager,
        didReceiveIncomingCallWithUserInfo userInfo: [AnyHashable: Any] = [:]
    ) {
        // we do not have calls
    }
}
