import Foundation
import NetworkExtension
import Shared
import PromiseKit

@available(iOS 14, *)
class NotificationAppPushHandler: NSObject, NEAppPushDelegate {
    private var manager: NEAppPushManager?

    override init() {
        super.init()

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

    private func updateManager() -> Promise<Void> {
        guard
            let connectionInfo = Current.settingsStore.connectionInfo,
            connectionInfo.internalSSIDs?.isEmpty == false,
            connectionInfo.internalURL != nil
        else {
            return Promise { seal in
                guard let manager = self.manager else {
                    Current.Log.info("no local push - no internal info")
                    seal.fulfill(())
                    return
                }

                Current.Log.info("removing manager \(manager) due to no internal info")
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

        manager.isEnabled = true
        manager.localizedDescription = "Where does this show up?"
        manager.providerBundleIdentifier = Constants.BundleID + ".PushProvider"
        manager.matchSSIDs = Current.settingsStore.connectionInfo?.internalSSIDs ?? []

        return Promise { seal in
            manager.saveToPreferences { error in
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
