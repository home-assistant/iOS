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
    }

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
            WebhookResponseUpdateComplications.updateComplications()
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
        case complicationChanged
        case serversChanged

        /// Human-readable text used in logs and client events.
        public var logDescription: String {
            switch self {
            case .complicationChanged: return "complication changed"
            case .serversChanged: return "servers changed"
            }
        }
    }

    /// Window over which repeated triggers coalesce into a single push.
    public static let debounceInterval: TimeInterval = 3
    /// Serial queue guarding the de-dup cache and debounce work item.
    private static let queue = DispatchQueue(label: AppConstants.BundleID + ".watchMirrorPush")
    private static var pendingWork: DispatchWorkItem?
    private static var lastPushedData: Data?

    /// Request a push. Safe to call from anywhere and as often as needed — it debounces and de-dupes.
    public static func schedule(reason: Reason) {
        queue.async {
            pendingWork?.cancel()
            let work = DispatchWorkItem { push(reason: reason) }
            pendingWork = work
            queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
        }
    }

    /// Clear the de-dup cache so the next `schedule` pushes even if the snapshot is unchanged. Used
    /// after a failed transfer and by tests.
    public static func reset() {
        queue.async { lastPushedData = nil }
    }

    private static func push(reason: Reason) {
        guard case .paired(.installed) = Communicator.shared.currentWatchState else {
            Current.Log.verbose("Skip watch mirror push (\(reason.logDescription)): watch unavailable")
            return
        }
        let data: Data
        let digests: [String: String]
        do {
            let snapshot = try WatchDatabaseMirror.snapshot()
            data = try snapshot.encodeForWatch()
            digests = snapshot.tableDigests()
        } catch {
            Current.Log.error("Watch mirror push snapshot failed (\(reason.logDescription)): \(error)")
            Current.clientEventStore.addEvent(.init(
                text: "Watch mirror push failed to build (\(reason.logDescription)): \(error.localizedDescription)",
                type: .database
            ))
            return
        }
        if data == lastPushedData {
            Current.Log.verbose("Skip watch mirror push (\(reason.logDescription)): unchanged")
            return
        }
        lastPushedData = data
        // The digests travel in the file-transfer metadata so the watch can store them after
        // applying this full mirror — keeping its next delta sync request accurate.
        Communicator.shared.transfer(HAWatchConnectivity.Blob(
            identifier: WatchDatabaseMirror.blobIdentifier,
            content: data,
            metadata: [WatchDatabaseMirror.digestsKey: digests]
        )) { result in
            if case let .failure(error) = result {
                Current.Log.error("Watch mirror push transfer failed (\(reason.logDescription)): \(error)")
                queue.async { lastPushedData = nil }
            }
        }
        Current.clientEventStore.addEvent(.init(
            text: "Pushed watch database mirror to Apple Watch (\(data.count) bytes) — \(reason.logDescription)",
            type: .database,
            payload: ["reason": reason.rawValue, "bytes": data.count]
        ))
    }
}
#endif
