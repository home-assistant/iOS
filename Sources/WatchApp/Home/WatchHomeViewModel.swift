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
    /// Whether the database actually holds a config row. False until the first successful cache
    /// read of a synced config — used to auto-retry the sync when the database is truly empty,
    /// without re-syncing for a config that legitimately has no items.
    private(set) var hasCachedConfig = false
    /// Changes every time a new config is fetched, used as a `.id()` modifier on lists to force re-render.
    @Published var configVersion = UUID()
    /// Set when the watch and iPhone both changed the config since the last sync; the UI prompts the
    /// user to choose which to keep.
    @Published var pendingConflict: ConfigConflict?
    /// Set when a server was skipped by the direct sync because its only URL is internal and the
    /// watch can't verify the home network. The UI asks the user whether to use that URL anyway
    /// (which sets the existing per-server "Always use" override).
    @Published var internalURLPrompt: WatchInternalURLPromptContext?
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
    /// Reloads the cache when the direct websocket sync refreshes the reference tables.
    private var directSyncObserver: NSObjectProtocol?

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
        // Reference tables (entities, areas, pipelines) now refresh over the server's websocket,
        // possibly while this screen is visible — re-resolve names/areas from the fresh rows.
        self.directSyncObserver = NotificationCenter.default.addObserver(
            forName: .watchDirectDatabaseSyncDidFinish,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.loadCache() }
        }
    }

    deinit {
        if let guaranteedObserver {
            Communicator.shared.guaranteedMessage.unobserve(guaranteedObserver)
        }
        if let directSyncObserver {
            NotificationCenter.default.removeObserver(directSyncObserver)
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
    private func enqueueGuaranteedConfigPull() {
        let identifier = InteractiveImmediateMessages.watchConfig.rawValue
        // Every reload while unreachable would otherwise queue another transferUserInfo, and the
        // phone would answer each with a full config payload once it wakes.
        guard !Communicator.shared.hasOutstandingGuaranteedMessage(identifier: identifier) else {
            Current.Log.info("Skipping guaranteed config pull: one is already queued")
            return
        }
        Communicator.shared.send(HAWatchConnectivity.GuaranteedMessage(identifier: identifier))
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
        // Reference data (entity registry, entities, zones, devices, areas, pipelines) comes
        // straight from the server over websocket — run it regardless of iPhone reachability.
        // Only the phone-owned data below (watch config, complications, servers, certificates)
        // still needs the phone.
        runDirectSync(userInitiated: userInitiated)
        homeType = .undefined
        guard Communicator.shared.currentReachability != .notReachable else {
            Current.Log.error("iPhone reachability is not immediate reachable")
            loadCache()
            // Queue a background pull so the phone answers once it's reachable again, then updates the
            // screen via the guaranteed-response reconcile — no need for the phone to be foreground.
            setLoadingStatus(L10n.Watch.Home.Sync.waiting)
            enqueueGuaranteedConfigPull()
            // No alert here: the direct sync launched above refreshes the reference data without
            // the phone. `runDirectSync` alerts only if that ALSO couldn't reach anything, so a
            // reload that actually refreshed data doesn't claim to have failed.
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

    /// Refresh the reference tables directly from the server(s). Failures are non-blocking —
    /// GRDB keeps the last-good rows — but a user-initiated reload that refreshed NOTHING must
    /// say so: every server failed → the server-unreachable error; nothing even attempted (no
    /// usable URL) while the phone is also away → the phone-not-reachable alert. Any success
    /// stays silent — the reload worked.
    @MainActor
    private func runDirectSync(userInitiated: Bool) {
        Task { [weak self] in
            let outcomes = await Current.watchDirectDatabaseSync.syncAll(force: userInitiated)
            await MainActor.run {
                self?.offerInternalURLIfNeeded(for: outcomes)
            }
            guard userInitiated else { return }
            guard !outcomes.contains(where: { $0.status == .success }) else { return }
            let allFailed = !outcomes.isEmpty && outcomes.allSatisfy {
                if case .failed = $0.status { return true }
                return false
            }
            await MainActor.run {
                guard let self else { return }
                if allFailed {
                    self.errorMessage = L10n.Watch.Sync.Error.serverUnreachable
                    self.showError = true
                } else if Communicator.shared.currentReachability == .notReachable {
                    self.showNotReachableAlert = true
                }
            }
        }
    }

    // MARK: - Internal URL consent prompt

    /// A server skipped for "no reachable URL" that HAS an internal URL is only unreachable
    /// because the watch can't verify the home network. Ask the user (once — "No" is remembered)
    /// whether to use that URL anyway; "Yes" sets the same per-server override as the settings
    /// picker. One prompt at a time; further servers get asked on subsequent syncs.
    @MainActor
    private func offerInternalURLIfNeeded(for outcomes: [WatchDirectSyncOutcome]) {
        guard internalURLPrompt == nil else { return }
        let skippedIds = outcomes.compactMap { outcome -> String? in
            guard case let .skipped(reason) = outcome.status,
                  reason == WatchDirectSyncOutcome.noReachableURLReason else { return nil }
            return outcome.serverId
        }
        guard !skippedIds.isEmpty else { return }
        for server in Current.servers.all where skippedIds.contains(server.identifier.rawValue) {
            let serverId = server.identifier.rawValue
            guard let internalURL = server.info.connection.internalURL,
                  WatchUserDefaults.shared.urlOverrideRawValue(forServerId: serverId) == nil,
                  !WatchUserDefaults.shared.internalURLPromptDeclined(forServerId: serverId) else { continue }
            internalURLPrompt = WatchInternalURLPromptContext(
                serverId: serverId,
                serverName: server.info.name,
                internalURL: internalURL
            )
            return
        }
    }

    /// "Yes": persist the internal URL as this server's override (same storage the settings
    /// picker uses), re-resolve the live servers, and sync right away.
    @MainActor
    func acceptInternalURLPrompt(_ prompt: WatchInternalURLPromptContext) {
        internalURLPrompt = nil
        WatchUserDefaults.shared.setURLOverrideRawValue(
            ConnectionInfo.URLType.internal.rawValue,
            forServerId: prompt.serverId
        )
        WatchServerSync.applyURLOverrides()
        Task { await Current.watchDirectDatabaseSync.syncAll(force: true) }
    }

    /// "No": remember the decline so the prompt never nags again; the settings URL override
    /// remains the way to opt in later.
    @MainActor
    func declineInternalURLPrompt(_ prompt: WatchInternalURLPromptContext) {
        internalURLPrompt = nil
        WatchUserDefaults.shared.setInternalURLPromptDeclined(true, forServerId: prompt.serverId)
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
        magicItemsInfo.first(where: {
            $0.id == magicItem.serverUniqueId
        }) ?? .init(
            id: magicItem.id,
            name: magicItem.id,
            iconName: ""
        )
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
    /// How many chunk requests may be outstanding at once. Overlapping requests hide the
    /// per-message round-trip latency that made the sync strictly serial (one full round trip per
    /// 30 KB chunk).
    private static let syncPipelineWindow = 3

    /// Kick off a full database sync. Requires the phone reachable (interactive request/reply); if it
    /// isn't, surface a friendly message rather than hang, and still try the config pull from cache.
    @MainActor
    private func startDatabaseSync() {
        guard Communicator.shared.currentReachability == .immediatelyReachable else {
            failSync(L10n.Watch.Sync.Error.unreachable)
            return
        }
        resetSyncState()
        // Echo the digests from the last applied mirror so the phone can omit unchanged tables.
        var content: [String: Any] = [:]
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
                Current.Log.error("Database sync start failed: \(error.localizedDescription)")
                self?.failSync(
                    L10n.Watch.Sync.Error.unreachable,
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
        let data = chunks.keys.sorted().compactMap { chunks[$0] }.reduce(Data(), +)
        let responseDigests = syncResponseDigests
        resetSyncState()
        let mirror: WatchDatabaseMirror
        do {
            mirror = try WatchDatabaseMirror.decodeForWatchThrowing(data)
        } catch {
            failSync(L10n.Watch.Sync.Error.data, detail: "decode failed (\(data.count) bytes): \(error)")
            return
        }
        do {
            try mirror.apply()
            // Only a successfully applied mirror advances the delta-sync baseline.
            WatchUserDefaults.shared.databaseMirrorDigests = responseDigests
            Current.Log.info("Applied watch database mirror (\(data.count) bytes)")
            Current.clientEventStore.addEvent(.init(
                text: "Apple Watch database sync applied (\(data.count) bytes)",
                type: .database
            ))
            // The sync also refreshes the servers carried by the mirror (in addition to the dedicated
            // serversConfigSync exchange kicked off at the start of the reload).
            WatchServerSync.applyMirroredServers(mirror.servers)
            // The mirror carries complications too — rebuild widget snapshots now so a reload is another
            // chance to obtain them if the background context push hasn't delivered them yet.
            WatchWidgetComplicationSnapshotStore.update()
        } catch {
            failSync(L10n.Watch.Sync.Error.data, detail: "apply to database failed: \(error)")
            return
        }
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

        let provider = Current.magicItemProvider()
        provider.loadInformation { [weak self] _ in
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
                self.resetError()
                self.finishCacheLoad()
            }
        }
    }

    /// Re-evaluates whether any server lacks a usable URL, feeding the settings gear's yellow
    /// attention dot. Piggybacks on every cache load so the dot follows server/URL-override changes
    /// without its own observation.
    private func refreshServerURLAttention() {
        Task { [weak self] in
            let needsAttention = !(await WatchServerURLAttention.serverIdsNeedingAttention().isEmpty)
            await MainActor.run { [weak self] in
                self?.settingsNeedsAttention = needsAttention
            }
        }
    }

    @MainActor
    private func updateConfig(config: WatchConfig, magicItemsInfo: [MagicItem.Info]) {
        watchConfig = config
        self.magicItemsInfo = magicItemsInfo
        configVersion = UUID()

        if config.assist.showAssist,
           config.assist.serverId != nil,
           config.assist.pipelineId != nil {
            showAssist = true
        } else {
            showAssist = false
        }
    }

    @MainActor
    private func finishCacheLoad() {
        guard !isSyncInFlight else { return }
        updateLoading(isLoading: false)
    }

    private func updateLoading(isLoading: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = isLoading
            if !isLoading {
                // Loading is over — the sync (if any) has reached a terminal state, so a new reload may
                // start. Cancel any pending throttled status update and clear immediately.
                self?.isSyncInFlight = false
                self?.pendingStatusWork?.cancel()
                self?.pendingStatusWork = nil
                self?.loadingStatus = nil
                self?.syncProgress = nil
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
