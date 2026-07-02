import Communicator
import Foundation
import Shared

/// The shared "pull latest servers + mTLS certificates from the phone" routine, used by both the
/// Home refresh button and the Settings screens. The phone replies to `serversConfigSync` with the
/// encoded servers and any client certificate bundles inline; both are applied to the local Keychain.
enum WatchServerSync {
    static func request() {
        guard Communicator.shared.currentReachability == .immediatelyReachable else {
            Current.Log.info("[Watch] Skipping server sync, iPhone not immediately reachable")
            return
        }
        Communicator.shared.send(.init(
            identifier: InteractiveImmediateMessages.serversConfigSync.rawValue,
            reply: { message in
                DispatchQueue.main.async {
                    apply(message)
                }
            }
        ), errorHandler: { error in
            Current.Log.error("[Watch] Failed to request servers sync: \(error)")
        })
    }

    private static func apply(_ message: ImmediateMessage) {
        if let serversData = message.content["servers"] as? Data {
            WatchUserDefaults.shared.set(Date(), key: .serversUpdatedAt)
            Current.servers.restoreState(serversData)
            applyURLOverrides()
        }
        if let certificatesData = message.content["clientCertificates"] as? Data {
            importCertificates(certificatesData)
        }
    }

    /// Re-apply each server's watch-local "Always use" URL choice. `ConnectionInfo` is overwritten on
    /// every sync, so the override (stored in `WatchUserDefaults`) must be re-applied to the live
    /// servers. Run on launch, after each sync, and whenever the picker changes.
    static func applyURLOverrides() {
        var changed: [Identifier<Server>] = []
        for server in Current.servers.all {
            let desired = WatchUserDefaults.shared
                .urlOverrideRawValue(forServerId: server.identifier.rawValue)
                .flatMap(ConnectionInfo.URLType.init(rawValue:))
            guard server.info.connection.overrideActiveURLType != desired else { continue }
            server.update { $0.connection.overrideActiveURLType = desired }
            changed.append(server.identifier)
        }
        if !changed.isEmpty {
            Current.resetAPICache(for: changed)
        }
    }

    /// Import inline client certificate bundle(s) into the watch Keychain, rebuild any affected API
    /// (session delegates are configured at init time), and refresh any visible mTLS status.
    private static func importCertificates(_ data: Data) {
        let imported = ClientCertificateManager.shared.importTransferPayload(data)
        guard !imported.isEmpty else { return }

        let affected = Current.servers.all.filter {
            guard let id = $0.info.connection.clientCertificate?.keychainIdentifier else { return false }
            return imported.contains(id)
        }.map(\.identifier)
        Current.resetAPICache(for: affected)

        NotificationCenter.default.post(name: .clientCertificatesImported, object: nil)
    }
}
