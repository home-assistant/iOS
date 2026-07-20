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

    private static func apply(_ message: HAWatchConnectivity.ImmediateMessage) {
        if let serversData = message.content["servers"] as? Data {
            applyServersState(serversData)
        }
        if let certificatesData = message.content["clientCertificates"] as? Data {
            importCertificates(certificatesData)
        }
    }

    /// Apply the servers carried by a database mirror (chunked pull or background push). The mirror
    /// keeps mTLS Keychain material off of it, so when a restored server references a client
    /// certificate the local Keychain doesn't have yet, follow up with a full `serversConfigSync`
    /// (which delivers the bundles inline) as soon as the phone is reachable.
    static func applyMirroredServers(_ data: Data?) {
        guard let data else { return }
        applyServersState(data)
        // Keychain lookups (SecItemCopyMatching) are too slow for the main thread this runs on, so
        // check off-main; pushed mirrors also often arrive while the phone isn't immediately
        // reachable, so the follow-up request waits for reachability instead of being dropped.
        let servers = Current.servers.all
        DispatchQueue.global(qos: .utility).async {
            let missingCertificate = servers.contains { server in
                guard let certificate = server.info.connection.clientCertificate else { return false }
                return !ClientCertificateManager.shared.hasIdentity(for: certificate)
            }
            guard missingCertificate else { return }
            Current.Log.info("[Watch] Mirrored servers reference a client certificate not in the Keychain")
            DispatchQueue.main.async { requestWhenReachable() }
        }
    }

    /// One-shot reachability observation guarding the deferred certificate request. Main-thread only.
    private static var reachabilityToken: HAWatchConnectivity.ObservationToken?

    /// Run `request()` now if the phone is immediately reachable, otherwise once it becomes so.
    /// Must be called on the main thread (observer callbacks also arrive there).
    private static func requestWhenReachable() {
        guard Communicator.shared.currentReachability != .immediatelyReachable else {
            request()
            return
        }
        guard reachabilityToken == nil else { return }
        reachabilityToken = Communicator.shared.reachability.observe { reachability in
            guard reachability == .immediatelyReachable, let token = reachabilityToken else { return }
            Communicator.shared.reachability.unobserve(token)
            reachabilityToken = nil
            request()
        }
    }

    private static func applyServersState(_ data: Data) {
        WatchUserDefaults.shared.set(Date(), key: .serversUpdatedAt)
        Current.servers.restoreState(data)
        applyURLOverrides()
        // A newly added server should populate its reference data (entities, areas, pipelines)
        // right away instead of waiting for the next foreground. Throttled internally.
        Task { await Current.watchDirectDatabaseSync.syncAll(force: false) }
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
