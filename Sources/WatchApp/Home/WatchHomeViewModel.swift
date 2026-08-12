import Foundation
import PromiseKit
import Shared
import SwiftUI

enum WatchHomeType {
    case undefined
    case empty
    case config(watchConfig: WatchConfig, magicItemsInfo: [MagicItem.Info])
    case error(message: String)
}

final class WatchHomeViewModel: ObservableObject {
    @Published var isLoading = false
    /// Short status shown under the progress bar while syncing (e.g. "Syncing with iPhone…"). `nil`
    /// when idle.
    @Published var loadingStatus: String?
    /// 0...1 progress for the database sync, or `nil` for indeterminate. Drives the header progress bar.
    @Published var syncProgress: Double?
    @Published var showAssist = false
    @Published var showError = false
    @Published var errorMessage = ""
    /// Set when the user taps reload but the iPhone isn't reachable, so the view can explain why instead
    /// of appearing to do nothing.
    @Published var showNotReachableAlert = false
    @Published private(set) var homeType: WatchHomeType = .undefined

    @Published var watchConfig: WatchConfig = .init()
    @Published var magicItemsInfo: [MagicItem.Info] = []
    /// Retained across cache loads so `info(for:)` can resolve entities that aren't configured home
    /// items — the ones the area screens push. `Current.magicItemProvider()` hands back an empty
    /// instance every call, so the loaded one has to be kept rather than rebuilt per lookup.
    private let magicItemProvider = Current.magicItemProvider()
    /// How the home screen presents the automatic area rows; recomputed on every cache load so it
    /// follows config edits and mirror syncs.
    @Published private(set) var areasMode: WatchHomeAreasMode = .hidden
    /// Whether the database actually holds a config row. False until the first successful cache
    /// read of a synced config — used to auto-retry the sync when the database is truly empty,
    /// without re-syncing for a config that legitimately has no items.
    private(set) var hasCachedConfig = false
    /// Changes every time a new config is fetched, used as a `.id()` modifier on lists to force re-render.
    @Published var configVersion = UUID()
    /// Set when the watch and iPhone both changed the config since the last sync; the UI prompts the
    /// user to choose which to keep.
    @Published var pendingConflict: ConfigConflict?
    /// True when any synced server currently resolves no usable URL from the watch — its magic
    /// items can't run. Surfaces as a yellow dot on the home footer's settings gear, pointing the
    /// user at the per-server warnings in Settings.
    @Published private(set) var settingsNeedsAttention = false

    /// True while a config/database sync is running. A second `requestConfig` is ignored until it
    /// finishes, so repeated reload taps can't stack several syncs (each holding a 30s reply timeout)
    /// in parallel.
    private var isSyncInFlight = false
    /// Whether the running sync was explicitly requested by the user (reload tap / retry). Failures of
    /// the automatic launch sync stay silent — the cache is already on screen — while user-initiated
    /// syncs surface an error alert.
    private var isSyncUserInitiated = false

    /// Registration for background (`transferUserInfo`) config responses from the phone.
    private var guaranteedObserver: HAWatchConnectivity.ObservationToken?

    /// Minimum time each `loadingStatus` value stays on screen, so rapid chunk progress doesn't blink
    /// through numbers too fast to read.
    private static let minStatusDisplay: TimeInterval = 0.4
    private var lastStatusChangeAt: Date?
    private var pendingStatusWork: DispatchWorkItem?

    /// Set the status text, but never faster than `minStatusDisplay`; rapid updates coalesce to the
    /// latest value once the minimum on-screen time for the previous one has elapsed. Must be called on
    /// the main thread (all call sites are).
    private func setLoadingStatus(_ status: String?) {
        pendingStatusWork?.cancel()
        pendingStatusWork = nil

        let now = Current.date()
        let elapsed = lastStatusChangeAt.map { now.timeIntervalSince($0) } ?? .greatestFiniteMagnitude
        if elapsed >= Self.minStatusDisplay {
            loadingStatus = status
            lastStatusChangeAt = now
            return
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            loadingStatus = status
            lastStatusChangeAt = Current.date()
            pendingStatusWork = nil
        }
        pendingStatusWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (Self.minStatusDisplay - elapsed), execute: work)
    }

    init() {
        // The phone answers a background config pull with a guaranteed message; route it through the
        // same conflict-aware reconcile as the interactive reply so offline edits aren't clobbered.
        self.guaranteedObserver = Communicator.shared.guaranteedMessage.observe { [weak self] message in
            Task { @MainActor in self?.handleGuaranteedConfigResponse(message) }
        }
    }

    deinit {
        if let guaranteedObserver {
            Communicator.shared.guaranteedMessage.unobserve(guaranteedObserver)
        }
    }

    @MainActor
    private func handleGuaranteedConfigResponse(_ message: HAWatchConnectivity.GuaranteedMessage) {
        switch message.identifier {
        case InteractiveImmediateResponses.watchConfigResponse.rawValue,
             InteractiveImmediateResponses.emptyWatchConfigResponse.rawValue:
            reconcile(with: HAWatchConnectivity.ImmediateMessage(
                identifier: message.identifier,
                content: message.content
            ))
        default:
            break
        }
    }

    /// Queue a config pull over `transferUserInfo` so the phone answers it in the background even when
    /// it wasn't immediately reachable. Used as a fallback when the interactive request can't run or
    /// times out.
    ///
    /// Runs off-main: both the outstanding-transfers read and `transferUserInfo` go through
    /// WCSession's internal serial queue, which can stall for tens of seconds while the session is
    /// busy with transfers — the same condition that leaves `isReachable` stale-false and lands a
    /// reload in this fallback. On main those calls froze the whole app; the pull is fire-and-forget,
    /// so a delayed enqueue is harmless. A private serial queue (not a global one) so a stuck call
    /// costs one overcommit thread instead of draining GCD's limited worker budget, and repeated
    /// reloads queue behind it rather than parking more threads.
    private static let guaranteedPullQueue = DispatchQueue(label: "guaranteed-config-pull", qos: .utility)

    private func enqueueGuaranteedConfigPull() {
        let identifier = InteractiveImmediateMessages.watchConfig.rawValue
        Self.guaranteedPullQueue.async {
            let started = Current.date()
            // Every reload while unreachable would otherwise queue another transferUserInfo, and the
            // phone would answer each with a full config payload once it wakes.
            guard !Communicator.shared.hasOutstandingGuaranteedMessage(identifier: identifier) else {
                Current.Log.info("Skipping guaranteed config pull: one is already queued")
                return
            }
            Communicator.shared.send(HAWatchConnectivity.GuaranteedMessage(identifier: identifier))
            let elapsed = Current.date().timeIntervalSince(started)
            if elapsed > 1 {
                let seconds = String(format: "%.2f", elapsed)
                Current.Log.error(
                    "Guaranteed config pull took \(seconds)s to enqueue — WCSession queue is stalled"
                )
            }
        }
    }

    @MainActor
    func initialRoutine() {
        // Cache-first: the last-known configuration renders synchronously from GRDB, so a cold open
        // never waits on (or gets blanked by) the sync below.
        loadCache()
        // Then refresh from the phone in the background. This is also what populates an empty
        // database (fresh install / wiped local data) — only the header shows progress, the cached
        // rows stay on screen throughout.
        isLoading = true
        requestConfig()
    }

    @MainActor
    func requestConfig(userInitiated: Bool = false) {
        // Re-entrancy guard: one sync at a time. Without this, tapping reload repeatedly stacks several
        // concurrent syncs — each interactive send holds a 30s reply timeout — which looks like the app
        // "hanging" with multiple refreshes in flight.
        guard !isSyncInFlight else {
            Current.Log.info("requestConfig ignored: a sync is already in flight")
            return
        }
        homeType = .undefined
        guard Communicator.shared.currentReachability != .notReachable else {
            Current.Log.info("iPhone is not immediately reachable")
            degradeToBackgroundPull(userInitiated: userInitiated)
            return
        }
        isSyncInFlight = true
        isSyncUserInitiated = userInitiated
        isLoading = true
        clearError()
        setLoadingStatus(L10n.Watch.Sync.starting)
        syncProgress = nil
        // Pull servers + any mTLS client certificates as part of the refresh (delivered inline).
        WatchServerSync.request()
        // Full reference-database sync (chunked, ordered, acknowledged). On completion it pulls the
        // watch config and clears loading; on failure it surfaces a friendly error.
        startDatabaseSync()
    }

    /// Fall back to a background pull when the phone isn't reachable, instead of failing the sync.
    ///
    /// Used both by the pre-send reachability check and by a send that came back with
    /// `WCError.notReachable`: the two are the same situation, only observed a few milliseconds apart.
    /// The queued guaranteed pull is answered whenever the phone comes back — no foreground needed —
    /// and updates the screen through the reconcile path.
    @MainActor
    private func degradeToBackgroundPull(userInitiated: Bool) {
        resetSyncState()
        // Cleared here rather than through `updateLoading`, which hops through the main queue: that
        // block would land after the status set below and blank it. Clearing `isSyncInFlight` also
        // keeps this abandoned sync from blocking a later reload.
        isLoading = false
        isSyncInFlight = false
        loadCache()
        setLoadingStatus(L10n.Watch.Home.Sync.waiting)
        enqueueGuaranteedConfigPull()
        // An explicit reload can't refresh now: tell the user the data will catch up in the
        // background once the phone is reachable again (the automatic sync stays silent).
        if userInitiated {
            showNotReachableAlert = true
        }
    }

    /// Pull the watch config from the phone and reconcile it (adopt / push offline edits / conflict).
    @MainActor
    private func pullWatchConfig() {
        Communicator.shared.send(.init(
            identifier: InteractiveImmediateMessages.watchConfig.rawValue,
            reply: { [weak self] message in
                Task { @MainActor in self?.reconcile(with: message) }
            }
        ), coalescingKey: InteractiveImmediateMessages.watchConfig.rawValue, errorHandler: { [weak self] error in
            // iPhone unreachable / slow / no reply within the timeout: fall back to the cached config so
            // the screen never hangs, and queue a background pull that survives the phone being asleep.
            Current.Log.error("Watch config request failed: \(error.localizedDescription)")
            Task { @MainActor in
                self?.loadCache()
                self?.updateLoading(isLoading: false)
                self?.enqueueGuaranteedConfigPull()
            }
        })
    }

    func info(for magicItem: MagicItem) -> MagicItem.Info {
        if let configured = magicItemsInfo.first(where: { $0.id == magicItem.serverUniqueId }) {
            return configured
        }
        // Not a configured home item — the area screens push entities the user never added, and
        // their info lives in the mirrored entity database instead. Resolving it here keeps every
        // pushed control screen titled with the entity's name rather than its id.
        if let resolved = magicItemProvider.getInfo(for: magicItem) {
            return resolved
        }
        return .init(id: magicItem.id, name: magicItem.id, iconName: "")
    }

    // MARK: - Offline-aware config reconciliation

    /// Handle the phone's reply to a config pull, deciding whether to adopt it, push local offline
    /// edits, or (when both sides changed) surface a conflict for the user to resolve.
    @MainActor
    private func reconcile(with message: HAWatchConnectivity.ImmediateMessage) {
        switch message.identifier {
        case InteractiveImmediateResponses.emptyWatchConfigResponse.rawValue:
            reconcile(phoneConfig: nil, phoneItemsInfo: [])
        case InteractiveImmediateResponses.watchConfigResponse.rawValue:
            guard let configData = message.content["config"] as? Data,
                  let phoneConfig = WatchConfig.decodeForWatch(configData),
                  let infoData = message.content["magicItemsInfo"] as? [Data] else {
                Current.Log.error("Failed to decode watch config response")
                loadCache()
                updateLoading(isLoading: false)
                return
            }
            reconcile(
                phoneConfig: phoneConfig,
                phoneItemsInfo: infoData.compactMap { MagicItem.Info.decodeForWatch($0) }
            )
        default:
            Current.Log.error("Received unmapped response id for watch config request, id: \(message.identifier)")
            loadCache()
            updateLoading(isLoading: false)
        }
    }

    @MainActor
    private func reconcile(phoneConfig: WatchConfig?, phoneItemsInfo: [MagicItem.Info]) {
        let localConfig = (try? WatchConfig.config()) ?? nil
        let baseline = WatchUserDefaults.shared.lastSyncedModified ?? 0
        let phoneModified = phoneConfig?.lastModified ?? 0
        let localModified = localConfig?.lastModified ?? 0
        let watchChanged = localConfig != nil && localModified != baseline
        let phoneChanged = phoneModified != baseline

        if !watchChanged {
            // Neither changed, or only the phone changed → take the phone's config.
            adopt(phoneConfig: phoneConfig, itemsInfo: phoneItemsInfo)
        } else if !phoneChanged {
            // Only the watch changed (offline edits) → push them to the phone.
            pushLocalConfig(localConfig)
        } else {
            // Both changed since the last sync → let the user decide.
            pendingConflict = ConfigConflict(phoneConfig: phoneConfig, phoneItemsInfo: phoneItemsInfo)
            updateLoading(isLoading: false)
        }
    }

    /// Overwrite the local config with the phone's and record it as the synced baseline.
    @MainActor
    func adopt(phoneConfig: WatchConfig?, itemsInfo: [MagicItem.Info]) {
        do {
            try Current.database().write { db in
                try WatchConfig.deleteAll(db)
                if var config = phoneConfig {
                    config.id = WatchConfig.watchConfigId
                    try config.insert(db, onConflict: .replace)
                }
            }
        } catch {
            Current.Log.error("Failed to adopt phone watch config: \(error.localizedDescription)")
        }
        WatchUserDefaults.shared.lastSyncedModified = phoneConfig?.lastModified
        pendingConflict = nil
        loadCache()
        updateLoading(isLoading: false)
    }

    /// Push the watch's local config to the phone (source of truth), then adopt the echoed result as
    /// the new synced baseline.
    @MainActor
    func pushLocalConfig(_ config: WatchConfig?) {
        guard let config else {
            adopt(phoneConfig: nil, itemsInfo: [])
            return
        }
        let configData: Data
        do {
            configData = try config.encodeForWatch()
        } catch {
            // The local copy stays as-is; it'll sync (or conflict-prompt) on the next reload.
            Current.Log.error("Failed to encode local watch config for push: \(error.localizedDescription)")
            loadCache()
            updateLoading(isLoading: false)
            return
        }
        Communicator.shared.send(.init(
            identifier: InteractiveImmediateMessages.watchConfigUpdate.rawValue,
            content: ["config": configData],
            reply: { [weak self] message in
                Task { @MainActor in self?.adoptPushReply(message) }
            }
        ), errorHandler: { [weak self] error in
            Current.Log.error("Failed to push watch config: \(error.localizedDescription)")
            Task { @MainActor in
                self?.loadCache()
                self?.updateLoading(isLoading: false)
            }
        })
    }

    @MainActor
    private func adoptPushReply(_ message: HAWatchConnectivity.ImmediateMessage) {
        if message.identifier == InteractiveImmediateResponses.watchConfigResponse.rawValue,
           let configData = message.content["config"] as? Data,
           let phoneConfig = WatchConfig.decodeForWatch(configData),
           let infoData = message.content["magicItemsInfo"] as? [Data] {
            adopt(phoneConfig: phoneConfig, itemsInfo: infoData.compactMap { MagicItem.Info.decodeForWatch($0) })
        } else {
            loadCache()
            updateLoading(isLoading: false)
        }
    }

    // MARK: - Chunked database sync (watch-driven, pipelined, assembled in index order)

    private var syncTransferId: String?
    private var syncTotalChunks = 0
    /// Received chunks by index; assembled in order once complete, so replies may arrive out of
    /// order without corrupting the payload.
    private var syncChunks: [Int: Data] = [:]
    /// Next chunk index that hasn't been requested yet.
    private var syncNextIndexToRequest = 0
    /// Digests issued with the sync-start reply; stored as the new baseline only after the mirror
    /// actually applies, so a failed sync keeps requesting the same tables.
    private var syncResponseDigests: [String: String]?
    /// Whether the sync-start reply flagged the payload as compressed. Trusted over the requested
    /// version: an older phone ignores the version and serves a plain (uncompressed) payload.
    private var syncResponseCompressed = false
    /// How many chunk requests may be outstanding at once. Overlapping requests hide the
    /// per-message round-trip latency that made the sync strictly serial (one full round trip per
    /// 30 KB chunk).
    private static let syncPipelineWindow = 3

    /// Kick off a full database sync. Requires the phone reachable (interactive request/reply); if it
    /// isn't, fall back to the background pull rather than hang or fail loudly.
    @MainActor
    private func startDatabaseSync() {
        guard Communicator.shared.currentReachability == .immediatelyReachable else {
            degradeToBackgroundPull(userInitiated: isSyncUserInitiated)
            return
        }
        resetSyncState()
        // Advertise the highest mirror version this build understands; the phone answers with the
        // matching snapshot fidelity (an older phone ignores the key and serves the legacy slice).
        var content: [String: Any] = [
            WatchDatabaseMirror.versionKey: WatchDatabaseMirror.fullReferenceVersion,
        ]
        // Echo the digests from the last applied mirror so the phone can omit unchanged tables.
        if let digests = WatchUserDefaults.shared.databaseMirrorDigests {
            content[WatchDatabaseMirror.digestsKey] = digests
        }
        Communicator.shared.send(.init(
            identifier: InteractiveImmediateMessages.watchDatabaseMirror.rawValue,
            content: content,
            reply: { [weak self] message in
                Task { @MainActor in self?.handleDatabaseSyncStart(message) }
            }
        ), priority: .background, errorHandler: { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                // Reachability flipped between the guard above and the send. That's transient, not a
                // failure worth alerting on — degrade to the background pull like the pre-check does.
                guard !HAWatchConnectivity.ConnectivityError.isCounterpartUnreachable(error) else {
                    Current.Log.info("Database sync start deferred: iPhone became unreachable mid-send")
                    self.degradeToBackgroundPull(userInitiated: self.isSyncUserInitiated)
                    return
                }
                Current.Log.error("Database sync start failed: \(error.localizedDescription)")
                self.failSync(
                    L10n.Watch.Sync.Error.generic,
                    detail: "sync start request failed: \(error.localizedDescription)"
                )
            }
        })
    }

    @MainActor
    private func handleDatabaseSyncStart(_ message: HAWatchConnectivity.ImmediateMessage) {
        guard message.content["error"] == nil,
              let transferId = message.content["transferId"] as? String,
              let totalChunks = message.content["totalChunks"] as? Int, totalChunks > 0 else {
            let phoneError = message.content["error"] as? String
            failSync(
                L10n.Watch.Sync.Error.generic,
                detail: phoneError.map { "iPhone reported: \($0)" }
                    ?? "sync start reply missing transferId/totalChunks (keys: \(message.content.keys.sorted()))"
            )
            return
        }
        syncTransferId = transferId
        syncTotalChunks = totalChunks
        syncChunks = [:]
        syncNextIndexToRequest = 0
        syncResponseDigests = message.content[WatchDatabaseMirror.digestsKey] as? [String: String]
        syncResponseCompressed = message.content[WatchDatabaseMirror.compressedKey] as? Bool ?? false
        Current.clientEventStore.addEvent(.init(
            text: "Apple Watch database sync started (\(totalChunks) chunks)",
            type: .database
        ))
        setLoadingStatus(L10n.Watch.Sync.progress(0, totalChunks))
        syncProgress = 0
        requestChunksUpToWindow()
    }

    /// Keep up to `syncPipelineWindow` chunk requests in flight, requesting indices in order.
    @MainActor
    private func requestChunksUpToWindow() {
        guard let transferId = syncTransferId else { return }
        while syncNextIndexToRequest < syncTotalChunks,
              syncNextIndexToRequest - syncChunks.count < Self.syncPipelineWindow {
            pullChunk(index: syncNextIndexToRequest, transferId: transferId)
            syncNextIndexToRequest += 1
        }
    }

    @MainActor
    private func pullChunk(index: Int, transferId: String) {
        Communicator.shared.send(.init(
            identifier: InteractiveImmediateMessages.watchDatabaseMirrorChunk.rawValue,
            content: ["transferId": transferId, "index": index],
            reply: { [weak self] message in
                Task { @MainActor in self?.handleChunk(message, index: index, transferId: transferId) }
            }
        ), priority: .background, errorHandler: { [weak self] error in
            Task { @MainActor in
                // Only the transfer that's still running may fail the sync; a straggler error from
                // a transfer that already failed (which reset the state) is just noise.
                guard self?.syncTransferId == transferId else { return }
                Current.Log.error("Database sync chunk \(index) failed: \(error.localizedDescription)")
                self?.failSync(
                    L10n.Watch.Sync.Error.generic,
                    detail: "chunk \(index) request failed: \(error.localizedDescription)"
                )
            }
        })
    }

    @MainActor
    private func handleChunk(_ message: HAWatchConnectivity.ImmediateMessage, index: Int, transferId: String) {
        // A late reply from a transfer that already failed or was replaced must not corrupt this one.
        guard syncTransferId == transferId else { return }
        guard message.content["error"] == nil, let chunk = message.content["chunkData"] as? Data else {
            let phoneError = message.content["error"] as? String
            failSync(
                L10n.Watch.Sync.Error.generic,
                detail: phoneError.map { "iPhone reported on chunk \(index): \($0)" }
                    ?? "chunk \(index) reply missing chunkData"
            )
            return
        }
        syncChunks[index] = chunk
        let received = syncChunks.count
        setLoadingStatus(L10n.Watch.Sync.progress(received, syncTotalChunks))
        syncProgress = Double(received) / Double(syncTotalChunks)
        if received == syncTotalChunks {
            finishDatabaseSync()
        } else {
            requestChunksUpToWindow()
        }
    }

    @MainActor
    private func finishDatabaseSync() {
        let chunks = syncChunks
        let responseDigests = syncResponseDigests
        let isCompressed = syncResponseCompressed
        resetSyncState()
        // Assembling, decompressing and decoding the payload — and the apply's full table rewrite —
        // are real work with the full-reference mirror, so they run off the main actor; only state
        // updates and the follow-up config pull hop back.
        Task.detached(priority: .userInitiated) { [weak self] in
            var data = chunks.keys.sorted().compactMap { chunks[$0] }.reduce(Data(), +)
            if isCompressed {
                do {
                    data = try WatchDatabaseMirror.decompress(data)
                } catch {
                    await self?.failSync(
                        L10n.Watch.Sync.Error.data,
                        detail: "decompress failed (\(data.count) bytes): \(error)"
                    )
                    return
                }
            }
            let mirror: WatchDatabaseMirror
            do {
                mirror = try WatchDatabaseMirror.decodeForWatchThrowing(data)
            } catch {
                await self?.failSync(
                    L10n.Watch.Sync.Error.data,
                    detail: "decode failed (\(data.count) bytes): \(error)"
                )
                return
            }
            do {
                try mirror.apply()
                // Only a successfully applied mirror advances the delta-sync baseline, and only for
                // the tables it actually carried — see `mergeDatabaseMirrorDigests`.
                WatchUserDefaults.shared.mergeDatabaseMirrorDigests(
                    responseDigests,
                    carrying: mirror.carriedDigestKeys
                )
                Current.Log.info("Applied watch database mirror (\(data.count) bytes)")
                Current.clientEventStore.addEvent(.init(
                    text: "Apple Watch database sync applied (\(data.count) bytes)",
                    type: .database
                ))
            } catch {
                await self?.failSync(L10n.Watch.Sync.Error.data, detail: "apply to database failed: \(error)")
                return
            }
            await self?.finishAppliedDatabaseSync(mirror: mirror)
        }
    }

    /// Main-actor tail of a successfully applied mirror: server refresh, widget snapshots and the
    /// follow-up config pull, all expected on the main thread (matching the pushed-mirror path).
    @MainActor
    private func finishAppliedDatabaseSync(mirror: WatchDatabaseMirror) {
        // The sync also refreshes the servers carried by the mirror (in addition to the dedicated
        // serversConfigSync exchange kicked off at the start of the reload).
        WatchServerSync.applyMirroredServers(mirror.servers)
        // The mirror carries complications too — rebuild widget snapshots now so a reload is another
        // chance to obtain them if the background context push hasn't delivered them yet.
        WatchWidgetComplicationSnapshotStore.update()
        // Reference tables are fresh — now pull the watch config and render everything from the DB.
        setLoadingStatus(L10n.Watch.Home.Sync.syncing)
        pullWatchConfig()
    }

    @MainActor
    private func failSync(_ friendlyMessage: String, detail: String? = nil) {
        resetSyncState()
        // The friendly message goes to the UI; the technical detail (which step failed and why) goes to
        // the log and the client-event payload so failures are actually diagnosable on-device.
        let logMessage = detail.map { "\(friendlyMessage) — \($0)" } ?? friendlyMessage
        Current.Log.error("Watch database sync failed: \(logMessage)")
        Current.clientEventStore.addEvent(.init(
            text: "Apple Watch database sync failed: \(logMessage)",
            type: .database,
            payload: detail.map { ["detail": $0] } ?? [:]
        ))
        // Only user-initiated syncs alert: the automatic launch sync fails silently onto the cache
        // that's already displayed (the failure is still logged/recorded above).
        if isSyncUserInitiated {
            errorMessage = friendlyMessage
            showError = true
        }
        updateLoading(isLoading: false)
        // Never leave the user with nothing: show whatever is cached locally.
        loadCache()
    }

    @MainActor
    private func resetSyncState() {
        syncTransferId = nil
        syncTotalChunks = 0
        syncChunks = [:]
        syncNextIndexToRequest = 0
        syncResponseDigests = nil
        syncResponseCompressed = false
        syncProgress = nil
    }

    @MainActor
    private func clearError() {
        errorMessage = ""
        showError = false
    }

    /// Render the home screen straight from the local GRDB — the config table plus names/icons/context
    /// resolved live by `MagicItemProvider` against the mirrored reference tables. No JSON cache: this
    /// mirrors how the iPhone watch-configuration editor resolves item info.
    @MainActor
    func loadCache(isRetry: Bool = false) {
        refreshServerURLAttention()
        let fetchedConfig: WatchConfig?
        do {
            fetchedConfig = try Current.database().read { db in try WatchConfig.fetchOne(db) }
        } catch {
            // A transient read failure must not blank the home screen: keep whatever config is
            // currently rendered (possibly from an earlier successful read) — the cache is only ever
            // replaced by data that actually loaded. Only alert when there's nothing on screen at all.
            // A cold open can race another process (the watch widget extension) holding the SQLite
            // lock, making this read time out even though the table has data. Retry once quietly —
            // a successful retry should not leave an error in the log or the client events.
            if !isRetry {
                Current.Log.info(
                    "Watch config cache read failed, retrying once: \(error.localizedDescription)"
                )
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    Task { @MainActor in self?.loadCache(isRetry: true) }
                }
                return
            }
            Current.Log.error("Failed to fetch watch config from database, error: \(error.localizedDescription)")
            Current.clientEventStore.addEvent(.init(
                text: "Failed to read watch config cache: \(error.localizedDescription)",
                type: .database
            ))
            if watchConfig.items.isEmpty {
                displayError(message: L10n.Watch.Config.Cache.Error.message)
            }
            finishCacheLoad()
            return
        }
        // Distinguishes "no config synced yet" (no row) from a config that legitimately has no
        // items, so the reachability retry only fires when the database is actually empty.
        hasCachedConfig = fetchedConfig != nil
        let config = fetchedConfig ?? WatchConfig()

        // Put the database-backed config on screen immediately. Item metadata can resolve a moment later,
        // but the user should not see the empty state while cached rows already exist.
        updateConfig(config: config, magicItemsInfo: magicItemsInfo)

        let provider = magicItemProvider
        provider.loadInformation { [weak self] entitiesPerServer in
            DispatchQueue.main.async {
                guard let self else { return }
                var infos: [MagicItem.Info] = []
                for item in config.items {
                    if let info = provider.getInfo(for: item) { infos.append(info) }
                    if item.type == .folder, let children = item.items {
                        for child in children {
                            if let info = provider.getInfo(for: child) { infos.append(info) }
                        }
                    }
                }
                self.updateConfig(config: config, magicItemsInfo: infos)
                self.updateAreasMode(config: config, entitiesPerServer: entitiesPerServer)
                self.resetError()
                self.finishCacheLoad()
            }
        }
    }

    /// Serial queue for the areas-mode computation — the area fetch is a synchronous database read
    /// that must stay off the main thread.
    private static let areasModeQueue = DispatchQueue(label: "watch-areas-mode", qos: .userInitiated)

    /// Recompute the automatic area rows from the mirrored areas and the entities the provider just
    /// loaded, filtered to what the home screen can actually render. Runs off-main and publishes
    /// the result back on the main queue.
    private func updateAreasMode(config: WatchConfig, entitiesPerServer: [String: [HAAppEntity]]) {
        Self.areasModeQueue.async { [weak self] in
            let allowedDomains = Set(Domain.watchAddable.map(\.rawValue))
            let watchEntityIdsByServer = entitiesPerServer.mapValues { entities in
                let watchEntities = entities.filter { $0.isWatchCompatible(allowedDomains: allowedDomains) }
                return Set(watchEntities.map(\.entityId))
            }
            let mode = WatchHomeAreasMode.compute(
                areas: (try? AppArea.fetchAllAreas()) ?? [],
                watchEntityIdsByServer: watchEntityIdsByServer,
                hideAreas: config.resolvedHideAreas
            )
            DispatchQueue.main.async { [weak self] in
                self?.areasMode = mode
            }
        }
    }

    /// Where the grouped "Areas" row goes: straight to the single server's areas, or through the
    /// server picker when several servers have them.
    func groupedAreasDestination() -> WatchHomeNavigation? {
        guard case let .grouped(serverIds) = areasMode else { return nil }
        if serverIds.count == 1, let serverId = serverIds.first {
            return .areasList(serverId: serverId)
        }
        return .areasServerPicker(serverIds: serverIds)
    }

    /// Re-evaluates whether any server lacks a usable URL, feeding the settings gear's yellow
    /// attention dot. Piggybacks on every cache load so the dot follows server/URL-override changes
    /// without its own observation.
    private func refreshServerURLAttention() {
        Task { [weak self] in
            let needingAttention = await WatchServerURLAttention.serverIdsNeedingAttention()
            await MainActor.run { [weak self] in
                self?.settingsNeedsAttention = !needingAttention.isEmpty
            }
        }
    }

    @MainActor
    private func updateConfig(config: WatchConfig, magicItemsInfo: [MagicItem.Info]) {
        let contentChanged = rendersDifferentContent(config: config, magicItemsInfo: magicItemsInfo)
        watchConfig = config
        self.magicItemsInfo = magicItemsInfo
        if contentChanged {
            configVersion = UUID()
        }

        if config.assist.showAssist,
           config.assist.serverId != nil,
           config.assist.pipelineId != nil {
            showAssist = true
        } else {
            showAssist = false
        }
    }

    /// Whether a freshly loaded config renders anything different from what's on screen.
    ///
    /// `configVersion` drives an `.id()` on the home list, which discards every row — including a row
    /// currently showing its run-confirmation dialog. Cache loads run on every sync (twice each: once
    /// for the cached config, once when the item info resolves), so re-issuing the id unconditionally
    /// dismissed that dialog under the user's finger while a sync completed. Only identical content may
    /// keep the current id.
    ///
    /// Items are compared through `contentHash`, not `==`: `MagicItem`'s equality is identity-based
    /// (id/server/type), so a renamed item, a recolored one or an edited folder child would otherwise
    /// read as unchanged — and the rows, whose view models capture the item when they're created,
    /// would keep rendering the old values.
    @MainActor
    private func rendersDifferentContent(config: WatchConfig, magicItemsInfo: [MagicItem.Info]) -> Bool {
        config.items.map(\.contentHash) != watchConfig.items.map(\.contentHash)
            || config.assist != watchConfig.assist
            || config.resolvedLayout != watchConfig.resolvedLayout
            || config.resolvedHideAreas != watchConfig.resolvedHideAreas
            || magicItemsInfo != self.magicItemsInfo
    }

    @MainActor
    private func finishCacheLoad() {
        guard !isSyncInFlight else { return }
        // The cache finishing rendering is not what ends a wait, so any status the caller deliberately
        // left up — "waiting for iPhone" after a deferred sync — stays on screen.
        updateLoading(isLoading: false, clearStatus: false)
    }

    private func updateLoading(isLoading: Bool, clearStatus: Bool = true) {
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = isLoading
            if !isLoading {
                // Loading is over — the sync (if any) has reached a terminal state, so a new reload may
                // start.
                self?.isSyncInFlight = false
                self?.syncProgress = nil
                if clearStatus {
                    // Cancel any pending throttled status update and clear immediately.
                    self?.pendingStatusWork?.cancel()
                    self?.pendingStatusWork = nil
                    self?.loadingStatus = nil
                }
            }
        }
    }

    private func displayError(message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = message
            self?.showError = true
        }
    }

    private func resetError() {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = ""
            self?.showError = false
        }
    }
}
