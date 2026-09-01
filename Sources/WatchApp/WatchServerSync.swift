import Foundation
import Shared

/// The shared "pull latest servers + mTLS certificates from the phone" routine, used by both the
/// Home refresh button and the Settings screens. The phone replies to `serversConfigSync` with the
/// encoded servers and any client certificate bundles inline; both are applied to the local Keychain.
enum WatchServerSync {
    /// Serial queue every server-state apply runs on. Restoring servers reads the Keychain and the
    /// GRDB mirror and writes both back per server — far too slow for the main thread (the watchdog
    /// killed the app waiting on the database queue behind burst mirror writes) — and serializing
    /// here keeps concurrent applies from racing `restoreState`.
    private static let applyQueue = DispatchQueue(label: "watch-server-sync-apply", qos: .utility)

    static func request() {
        guard Communicator.shared.currentReachability == .immediatelyReachable else {
            Current.Log.info("[Watch] Skipping server sync, iPhone not immediately reachable")
            return
        }
        Communicator.shared.send(.init(
            identifier: InteractiveImmediateMessages.serversConfigSync.rawValue,
            reply: { message in
                applyQueue.async {
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
        applyQueue.async { applyMirroredServersNow(data) }
    }

    /// Synchronous variant for a caller that must have the servers applied before it returns —
    /// the pushed-mirror path runs inside an expiring background activity, and work dispatched
    /// past its end would hit a re-suspended database.
    static func applyMirroredServersAndWait(_ data: Data?) {
        guard let data else { return }
        dispatchPrecondition(condition: .notOnQueue(.main))
        dispatchPrecondition(condition: .notOnQueue(applyQueue))
        applyQueue.sync { applyMirroredServersNow(data) }
    }

    private static func applyMirroredServersNow(_ data: Data) {
        applyServersState(data)
        // Already off-main here, so the Keychain lookups (SecItemCopyMatching) can run inline.
        // Pushed mirrors also often arrive while the phone isn't immediately reachable, so the
        // follow-up request waits for reachability instead of being dropped.
        guard hasMissingCertificate() else { return }
        Current.Log.info("[Watch] Mirrored servers reference a client certificate not in the Keychain")
        DispatchQueue.main.async { requestWhenReachable() }
    }

    /// Whether any configured server references a client certificate this Watch's Keychain lacks.
    /// Reads the Keychain, so it must not run on the main thread.
    private static func hasMissingCertificate() -> Bool {
        Current.servers.all.contains { server in
            guard let certificate = server.info.connection.clientCertificate else { return false }
            return !ClientCertificateManager.shared.hasIdentity(for: certificate)
        }
    }

    /// Pull the mTLS bundles from the phone when a configured server references a client certificate
    /// this Watch's Keychain doesn't have. Called at launch as well as after each mirror apply: the
    /// servers persisted from a previous run outlive the identity that went with them (the mirror is
    /// sanitized of Keychain material, and a Watch restored from a backup keeps neither), and without
    /// this every mTLS request fails with `certificateNotFound` for the process's whole lifetime with
    /// nothing asking the phone to re-send.
    static func requestCertificatesIfMissing() {
        applyQueue.async {
            guard hasMissingCertificate() else { return }
            Current.Log.info("[Watch] A configured server references a client certificate not in the Keychain")
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

        // Posted on main: WatchServerDetailView receives this straight into SwiftUI state.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .clientCertificatesImported, object: nil)
        }
    }
}
