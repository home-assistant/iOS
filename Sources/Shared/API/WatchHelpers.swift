import Foundation
import ObjectMapper
import PromiseKit
#if os(watchOS)
import ClockKit
import WatchKit
#endif

public extension HomeAssistantAPI {
    // Be mindful of 262.1kb maximum size for context - https://stackoverflow.com/a/35076706/486182
    private static func watchContext() async -> HAWatchConnectivity.Content {
        // Each side sends only the keys it owns (see WatchContext). The sent and received
        // application contexts are separate dictionaries in WCSession, so nothing is lost by not
        // echoing the counterpart's keys back — echoing only bloated every update toward the size
        // cap and could resurrect stale values (e.g. an old battery level bouncing back).
        var content: HAWatchConnectivity.Content = [:]

        #if os(iOS)
        // Servers are delivered on demand via the `serversConfigSync` interactive message (see
        // WatchCommunicatorService), mirroring how the watch configuration is fetched — not here.
        //
        // DEPRECATED wire path: current watch builds ignore these context keys entirely — the
        // complication tables reach the watch through the database mirror (transferFile/chunked
        // pull) and land in GRDB directly. They're still sent for one release cycle so older watch
        // builds keep receiving complications; remove them (and reassess whether the iOS context
        // sync is needed at all) after that.
        //
        // Only attach them when the read actually succeeds: sending an empty array on a read failure
        // would look authoritative to the watch and wipe its existing complications. A successful read
        // that happens to be empty IS authoritative (that is how deleting the last one propagates).
        if let complications = try? WatchComplication.all() {
            content[WatchContext.complications.rawValue] = (try? JSONEncoder().encode(complications)) ?? Data()
        }

        // Modern complications (entity/custom) are rendered by the watch itself.
        if let complicationConfigs = try? WatchComplicationConfig.all() {
            content[WatchContext.complicationConfigs.rawValue] =
                (try? JSONEncoder().encode(complicationConfigs)) ?? Data()
        }

        // The watch has no network info of its own and no longer reads a phone-synced SSID, so there's
        // nothing to send here.

        #elseif os(watchOS)

        let activeFamilies: [String]? = CLKComplicationServer.sharedInstance().activeComplications?.compactMap {
            ComplicationGroupMember(family: $0.family).rawValue
        }

        content[WatchContext.activeFamilies.rawValue] = activeFamilies
        content[WatchContext.watchModel.rawValue] = Current.device.systemModel()
        content[WatchContext.watchVersion.rawValue] = Current.device.systemVersion()
        let currentWatchInterfaceDevice = WKInterfaceDevice.current()
        currentWatchInterfaceDevice.isBatteryMonitoringEnabled = true
        content[WatchContext.watchBattery.rawValue] = currentWatchInterfaceDevice.batteryLevel
        content[WatchContext.watchBatteryState.rawValue] = currentWatchInterfaceDevice.batteryState.rawValue

        #endif

        return content
    }

    /// Sync the context unless it exceeds `updateApplicationContext`'s payload ceiling. On iOS the
    /// only keys are the complication tables, which the database mirror also carries — and
    /// `transferFile` has no size cap — so an oversized context is delivered through a mirror push
    /// instead of failing.
    private static func syncRespectingSizeLimit(_ context: HAWatchConnectivity.Context) throws {
        #if os(iOS)
        if let size = WatchConnectivityManager.estimatePayloadSize(of: context.content),
           size > WatchMessageSizeLimits.applicationContext {
            Current.Log.error(
                "Watch context is \(size) bytes, above the ~262 KB ceiling; delivering via database mirror push instead"
            )
            Current.clientEventStore.addEvent(.init(
                text: "Watch context too large to sync (\(size) bytes); scheduled database mirror push instead",
                type: .database
            ))
            WatchMirrorPushCoordinator.schedule(reason: .complicationChanged)
            return
        }
        #endif
        try Communicator.shared.sync(context)
    }

    static func SyncWatchContext() async -> NSError? {
        #if os(iOS)
        guard case .paired(.installed) = Communicator.shared.currentWatchState else {
            Current.Log.warning("Tried to sync HAAPI config to watch but watch not paired or app not installed")
            return nil
        }
        #endif

        let context = await HAWatchConnectivity.Context(content: HomeAssistantAPI.watchContext())

        #if os(watchOS)
        // `updateApplicationContext` waits synchronously on WCSession's internal operation queue,
        // which stalls indefinitely while the companion channel is wedged. This method runs in a
        // cooperative-pool task on every lifecycle transition, and the watch's cooperative pool is
        // only two threads wide — two stuck updates wedged the entire pool (and GCD's worker
        // budget with it), killing all async work in the app: direct sync, token refresh, even
        // URLSession callbacks for magic items. So the blocking call is handed to a dedicated
        // serial queue instead, gated to a single in-flight update, and never awaited here.
        enqueueWatchContextSync(context)
        return nil
        #else
        do {
            try syncRespectingSizeLimit(context)
            Current.Log.info("updated context")
            Current.clientEventStore.addEvent(.init(
                text: "Synced watch context to Apple Watch (updateApplicationContext)",
                type: .database
            ))
        } catch let error as NSError {
            Current.Log.error("Updating the context failed: \(error)")
            Current.clientEventStore.addEvent(.init(
                text: "Failed to sync watch context: \(error.localizedDescription)",
                type: .database
            ))
            return error
        }

        return nil
        #endif
    }

    #if os(watchOS)
    /// Dedicated home for the blocking `updateApplicationContext` call. A private serial queue
    /// runs on GCD's overcommit band, so a call stuck inside WCSession costs one extra thread
    /// without draining the worker budget the rest of the app depends on.
    private static let watchContextSyncQueue = DispatchQueue(label: "watch-context-sync", qos: .utility)
    private static let watchContextSyncGate = NSLock()
    private static var watchContextSyncInFlight = false
    /// The newest context that arrived while an update was in flight, delivered as soon as that update
    /// returns. Only the newest is kept — the ones it replaces are already obsolete.
    private static var pendingWatchContext: HAWatchConnectivity.Context?

    /// Hand the context to `updateApplicationContext` off the caller's thread, keeping at most one
    /// update in flight: a call stuck inside WCSession would otherwise park a thread per caller.
    /// Later contexts are coalesced rather than dropped — the in-flight call is carrying an *older*
    /// snapshot, so discarding the new one would strand the watch on stale data until some unrelated
    /// trigger happened to sync again.
    private static func enqueueWatchContextSync(_ context: HAWatchConnectivity.Context) {
        watchContextSyncGate.lock()
        guard !watchContextSyncInFlight else {
            pendingWatchContext = context
            watchContextSyncGate.unlock()
            Current.Log.info("Coalescing watch context sync: previous update still in flight (WCSession stalled?)")
            return
        }
        watchContextSyncInFlight = true
        watchContextSyncGate.unlock()

        watchContextSyncQueue.async {
            var next: HAWatchConnectivity.Context? = context
            while let current = next {
                syncWatchContextNow(current)
                // Claim the next context (or stand down) under the same lock the producer takes, so a
                // context enqueued right as this update finishes can't be stranded.
                watchContextSyncGate.lock()
                if let pending = pendingWatchContext {
                    next = pending
                    pendingWatchContext = nil
                } else {
                    next = nil
                    watchContextSyncInFlight = false
                }
                watchContextSyncGate.unlock()
            }
        }
    }

    /// The blocking `updateApplicationContext` call itself, always on `watchContextSyncQueue`.
    private static func syncWatchContextNow(_ context: HAWatchConnectivity.Context) {
        do {
            try syncRespectingSizeLimit(context)
            Current.Log.info("updated context")
            Current.clientEventStore.addEvent(.init(
                text: "Synced watch context to Apple Watch (updateApplicationContext)",
                type: .database
            ))
        } catch {
            Current.Log.error("Updating the context failed: \(error)")
            Current.clientEventStore.addEvent(.init(
                text: "Failed to sync watch context: \(error.localizedDescription)",
                type: .database
            ))
        }
    }
    #endif

    /// Fire-and-forget `SyncWatchContext()` for callers that cannot await; sync errors are logged
    /// by `SyncWatchContext()` itself.
    static func syncWatchContext() {
        Task {
            _ = await SyncWatchContext()
        }
    }

    /// Outcome of a user-initiated watch reload, so the iPhone UI can give real feedback instead of
    /// silently firing a sync.
    enum WatchReloadOutcome: Equatable {
        case success
        /// The watch isn't paired or the watch app isn't installed — nothing to sync to.
        case watchUnavailable
        case failed(String)
    }

    #if os(iOS)
    /// Push the current context to the watch and report whether it worked, for the Complications
    /// settings "Reload" button. Distinguishes "no watch" (so the UI can explain why) from a transport
    /// failure (so the UI can show the error).
    static func reloadWatchComplications() async -> WatchReloadOutcome {
        guard case .paired(.installed) = Communicator.shared.currentWatchState else {
            Current.Log.warning("Watch reload requested but watch not paired or app not installed")
            return .watchUnavailable
        }
        // Current watch builds read complications from the database mirror and ignore the context
        // keys below, so the reload has to travel that way too — and, once the rows land, ask the
        // watch to fetch their values and re-render. Without this the button only refreshed watches
        // old enough to still read the context.
        WatchMirrorPushCoordinator.schedule(reason: .complicationSaved)
        let context = await HAWatchConnectivity.Context(content: watchContext())
        do {
            try syncRespectingSizeLimit(context)
            Current.Log.info("Watch reload: context synced")
            return .success
        } catch {
            Current.Log.error("Watch reload failed: \(error.localizedDescription)")
            return .failed(error.localizedDescription)
        }
    }
    #endif

    func updateComplications(passively: Bool) -> Promise<Void> {
        #if os(iOS)
        guard case .paired = Communicator.shared.currentWatchState else {
            Current.Log.verbose("skipping complication updates; no paired watch")
            return .value(())
        }
        #endif

        let complications = (try? WatchComplication.all(forServerIdentifier: server.identifier.rawValue)) ?? []

        guard let request = WebhookResponseUpdateComplications.request(for: complications) else {
            Current.Log.verbose("no complications need templates rendered")

            #if os(iOS)
            // in case the user deleted the last complication, sync that fact up to the watch
            HomeAssistantAPI.syncWatchContext()
            #else
            // in case the user updated just the complication's metadata, force a refresh
            NotificationCenter.default.post(name: WatchComplication.didChangeNotification, object: nil)
            #endif

            return .value(())
        }

        if passively {
            return Current.webhooks.sendPassive(identifier: .updateComplications, server: server, request: request)
        } else {
            return Current.webhooks.send(identifier: .updateComplications, server: server, request: request)
        }
    }
}

#if os(iOS)
/// Coalesces and de-duplicates proactive pushes of the full watch database mirror to the Apple Watch
/// over `transferFile` (background-capable), so the watch always ends up with the latest reference data
/// without the user asking. Multiple triggers within `debounceInterval` collapse into a single push, and
/// a snapshot identical to the last-pushed one is skipped.
public enum WatchMirrorPushCoordinator {
    /// Why a push was requested — a typed value (not a bare string) so triggers, logging and tests all
    /// share the same source of truth.
    public enum Reason: String, CaseIterable {
        case databaseUpdated
        /// Complication data changed on its own — e.g. the server re-rendered a legacy complication's
        /// templates. Delivered like any other change; the watch rebuilds its faces when it applies
        /// the mirror.
        case complicationChanged
        /// The user created, edited, deleted or reordered a complication. Delivered *and* followed by
        /// a complication refresh request (see `WatchComplicationRefreshRequest`), so the face shows
        /// the change right after Save instead of at the watch's next periodic refresh. Kept apart
        /// from `complicationChanged` because that request spends one of the watch's budgeted
        /// background wakes, which belongs to a user action rather than to routine data flow.
        case complicationSaved
        case serversChanged
        case watchConfigChanged
        case notificationSnoozeActionsChanged

        /// Human-readable text used in logs and client events.
        public var logDescription: String {
            switch self {
            case .databaseUpdated: return "database updated"
            case .complicationChanged: return "complication changed"
            case .complicationSaved: return "complication saved"
            case .serversChanged: return "servers changed"
            case .watchConfigChanged: return "watch config changed"
            case .notificationSnoozeActionsChanged: return "notification snooze actions changed"
            }
        }
    }

    /// Window over which repeated triggers coalesce into a single push.
    public static let debounceInterval: TimeInterval = 3
    /// Serial queue guarding the de-dup cache and debounce work item.
    private static let queue = DispatchQueue(label: AppConstants.BundleID + ".watchMirrorPush")
    private static var pendingWork: DispatchWorkItem?
    private static var lastPushedData: Data?
    /// Whether any trigger coalesced into the pending push was a complication change, so the watch is
    /// told to re-render once it has the new rows. Tracked separately from the push's `reason`, which
    /// is only the newest trigger: a complication save followed by an unrelated trigger within the
    /// debounce window would otherwise silently lose its refresh.
    private static var pendingComplicationRefresh = false

    private static let peerMirrorVersionKey = "watchMirrorPeerVersion"

    /// The mirror version the paired watch advertised on its most recent sync request, persisted so
    /// proactive pushes keep serving the right fidelity across launches. Defaults to legacy until a
    /// versioned request arrives, and is overwritten by *every* request — including version-less
    /// ones — so pairing an older watch drops back to the legacy payload it can decode.
    public static var peerMirrorVersion: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: peerMirrorVersionKey)
            return stored == 0 ? WatchDatabaseMirror.legacyVersion : stored
        }
        set {
            UserDefaults.standard.set(newValue, forKey: peerMirrorVersionKey)
        }
    }

    /// Request a push. Safe to call from anywhere and as often as needed — it debounces and de-dupes.
    public static func schedule(reason: Reason) {
        queue.async {
            pendingComplicationRefresh = pendingComplicationRefresh || reason == .complicationSaved
            pendingWork?.cancel()
            let work = DispatchWorkItem { push(reason: reason) }
            pendingWork = work
            queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
        }
    }

    /// Digests of the tables the watch is believed to hold, from the last transfer this coordinator
    /// handed off. Used to omit unchanged tables from the next push: a full-reference snapshot is
    /// megabytes, and pushing all of it on every trigger saturates the WatchConnectivity link —
    /// starving the interactive chunked pull, whose sends then fail as "not immediately reachable".
    /// Cleared whenever a transfer fails, so the next push is complete again.
    ///
    /// Safe to be wrong: the watch adopts digests only for tables a payload actually carried, so a
    /// push it never applied leaves its stored digests untouched and its next pull asks for the
    /// tables it is really missing.
    private static var lastPushedDigests: [String: String] = [:]

    /// Clear the de-dup caches so the next `schedule` pushes a complete snapshot even if unchanged.
    /// Used after a failed transfer and by tests.
    public static func reset() {
        queue.async {
            lastPushedData = nil
            lastPushedDigests = [:]
        }
    }

    private static func push(reason: Reason) {
        // The debounce commonly fires after its trigger's own lifetime has ended — e.g. a background
        // URLSession or WatchConnectivity wake — so the snapshot read and transfer hand-off run under
        // a background task assertion, keeping the process alive instead of letting it be frozen
        // mid-read holding the app-group SQLite file lock (0xdead10cc).
        Current.backgroundTask(withName: BackgroundTask.watchMirrorPush.rawValue) { _ -> Promise<Void> in
            performPush(reason: reason)
            return .value(())
        }.cauterize()
    }

    private static func performPush(reason: Reason) {
        // Consumed up front: whether the watch gets asked to re-render is decided per push, and a
        // failed one leaves the ask to the next push rather than firing against data that never landed.
        let refreshesComplications = pendingComplicationRefresh
        pendingComplicationRefresh = false
        guard case .paired(.installed) = Communicator.shared.currentWatchState else {
            Current.Log.verbose("Skip watch mirror push (\(reason.logDescription)): watch unavailable")
            return
        }
        // Serve the fidelity the paired watch advertised on its last sync request; a full-reference
        // payload always travels compressed (and a legacy watch is never sent one — it couldn't
        // decode the compressed bytes, let alone want the unfiltered tables).
        let version = peerMirrorVersion
        let compressed = version >= WatchDatabaseMirror.fullReferenceVersion
        let data: Data
        let digests: [String: String]
        let carriedKeys: Set<String>
        do {
            let snapshot = try WatchDatabaseMirror.snapshot(version: version)
            digests = snapshot.tableDigests()
            // Carry only what changed since the last transfer, the same way the watch-initiated
            // pull does — a push that repeats the whole reference database would monopolize the
            // link every time anything changes.
            let payload = snapshot.omittingTables(matching: lastPushedDigests, currentDigests: digests)
            carriedKeys = payload.carriedDigestKeys
            guard !carriedKeys.isEmpty else {
                Current.Log.verbose("Skip watch mirror push (\(reason.logDescription)): no table changed")
                // Nothing to send, but the watch already holds the complications — let it re-render now.
                if refreshesComplications { WatchComplicationRefreshRequest.send() }
                return
            }
            let encoded = try payload.encodeForWatch()
            data = compressed ? try WatchDatabaseMirror.compress(encoded) : encoded
        } catch {
            Current.Log.error("Watch mirror push snapshot failed (\(reason.logDescription)): \(error)")
            Current.clientEventStore.addEvent(.init(
                text: "Watch mirror push failed to build (\(reason.logDescription)): \(error.localizedDescription)",
                type: .database
            ))
            // Nothing was sent, so keep the ask for the next push rather than dropping it.
            pendingComplicationRefresh = pendingComplicationRefresh || refreshesComplications
            return
        }
        if data == lastPushedData {
            Current.Log.verbose("Skip watch mirror push (\(reason.logDescription)): unchanged")
            if refreshesComplications { WatchComplicationRefreshRequest.send() }
            return
        }
        lastPushedData = data
        // Omitted tables matched these digests already, so the whole map describes what the watch
        // is believed to hold once this payload lands.
        lastPushedDigests = digests
        // The digests travel in the file-transfer metadata so the watch can store them — for the
        // tables this payload carried — keeping its next delta sync request accurate.
        var metadata: [String: Any] = [WatchDatabaseMirror.digestsKey: digests]
        if compressed {
            metadata[WatchDatabaseMirror.compressedKey] = true
        }
        Communicator.shared.transfer(HAWatchConnectivity.Blob(
            identifier: WatchDatabaseMirror.blobIdentifier,
            content: data,
            metadata: metadata
        )) { result in
            switch result {
            case .success:
                // The transfer completes on delivery, so the watch now holds the new complication
                // rows: this is the moment it can be told to fetch their values and re-render, rather
                // than waiting for its next periodic refresh.
                if refreshesComplications { WatchComplicationRefreshRequest.send() }
            case let .failure(error):
                Current.Log.error("Watch mirror push transfer failed (\(reason.logDescription)): \(error)")
                // The watch got nothing, so drop both beliefs: the next push rebuilds in full.
                queue.async {
                    lastPushedData = nil
                    lastPushedDigests = [:]
                    // The rows never landed, so re-arm the ask for the push that carries them.
                    pendingComplicationRefresh = pendingComplicationRefresh || refreshesComplications
                }
            }
        }
        Current.clientEventStore.addEvent(.init(
            text: "Pushed watch database mirror to Apple Watch (\(data.count) bytes, "
                + "\(carriedKeys.sorted().joined(separator: "+"))) — \(reason.logDescription)",
            type: .database,
            payload: ["reason": reason.rawValue, "bytes": data.count, "tables": carriedKeys.sorted()]
        ))
    }
}
#endif
