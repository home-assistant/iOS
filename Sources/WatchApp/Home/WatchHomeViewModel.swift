import Foundation
import Network
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
    @Published var currentSSID: String = ""
    @Published private(set) var homeType: WatchHomeType = .undefined

    @Published var watchConfig: WatchConfig = .init()
    @Published var magicItemsInfo: [MagicItem.Info] = []
    /// Changes every time a new config is fetched, used as a `.id()` modifier on lists to force re-render.
    @Published var configVersion = UUID()
    /// Set when the watch and iPhone both changed the config since the last sync; the UI prompts the
    /// user to choose which to keep.
    @Published var pendingConflict: ConfigConflict?

    /// True while a config/database sync is running. A second `requestConfig` is ignored until it
    /// finishes, so repeated reload taps can't stack several syncs (each holding a 30s reply timeout)
    /// in parallel.
    private var isSyncInFlight = false
    /// Whether the running sync was explicitly requested by the user (reload tap / retry). Failures of
    /// the automatic launch sync stay silent — the cache is already on screen — while user-initiated
    /// syncs surface an error alert.
    private var isSyncUserInitiated = false

    private var networkPathMonitor: NWPathMonitor?
    private let networkMonitorQueue = DispatchQueue(label: "WatchHomeNetworkPathMonitor")
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
        networkPathMonitor?.cancel()
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

    func startNetworkMonitoring() {
        guard networkPathMonitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] _ in
            Task { @MainActor in
                await self?.fetchNetworkInfo()
            }
        }
        monitor.start(queue: networkMonitorQueue)
        networkPathMonitor = monitor
    }

    @MainActor
    func fetchNetworkInfo() async {
        // `currentWiFiSSID()` fetches fresh network information itself.
        currentSSID = await Current.connectivity.currentWiFiSSID() ?? ""
    }

    @MainActor
    func initialRoutine() {
        // First display whatever is in cache
        loadCache()
        // Now fetch new data in the background (shows loading indicator only for this fetch)
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
            Current.Log.error("iPhone reachability is not immediate reachable")
            loadCache()
            // Queue a background pull so the phone answers once it's reachable again, then updates the
            // screen via the guaranteed-response reconcile — no need for the phone to be foreground.
            setLoadingStatus(L10n.Watch.Home.Sync.waiting)
            enqueueGuaranteedConfigPull()
            // Tell the user why an explicit reload appears to do nothing (background pull still runs).
            if userInitiated { showNotReachableAlert = true }
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

    /// Pull the watch config from the phone and reconcile it (adopt / push offline edits / conflict).
    @MainActor
    private func pullWatchConfig() {
        Communicator.shared.send(.init(
            identifier: InteractiveImmediateMessages.watchConfig.rawValue,
            reply: { [weak self] message in
                Task { @MainActor in self?.reconcile(with: message) }
            }
        ), errorHandler: { [weak self] error in
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

    // MARK: - Chunked database sync (watch-driven, ordered, acknowledged)

    private var syncTransferId: String?
    private var syncTotalChunks = 0
    private var syncAccumulated = Data()

    /// Kick off a full database sync. Requires the phone reachable (interactive request/reply); if it
    /// isn't, surface a friendly message rather than hang, and still try the config pull from cache.
    @MainActor
    private func startDatabaseSync() {
        guard Communicator.shared.currentReachability == .immediatelyReachable else {
            failSync(L10n.Watch.Sync.Error.unreachable)
            return
        }
        resetSyncState()
        Communicator.shared.send(.init(
            identifier: InteractiveImmediateMessages.watchDatabaseMirror.rawValue,
            reply: { [weak self] message in
                Task { @MainActor in self?.handleDatabaseSyncStart(message) }
            }
        ), errorHandler: { [weak self] error in
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
        syncAccumulated = Data()
        Current.clientEventStore.addEvent(.init(
            text: "Apple Watch database sync started (\(totalChunks) chunks)",
            type: .database
        ))
        setLoadingStatus(L10n.Watch.Sync.progress(0, totalChunks))
        syncProgress = 0
        pullChunk(index: 0)
    }

    @MainActor
    private func pullChunk(index: Int) {
        guard let transferId = syncTransferId else { return }
        Communicator.shared.send(.init(
            identifier: InteractiveImmediateMessages.watchDatabaseMirrorChunk.rawValue,
            content: ["transferId": transferId, "index": index],
            reply: { [weak self] message in
                Task { @MainActor in self?.handleChunk(message, index: index) }
            }
        ), errorHandler: { [weak self] error in
            Task { @MainActor in
                Current.Log.error("Database sync chunk \(index) failed: \(error.localizedDescription)")
                self?.failSync(
                    L10n.Watch.Sync.Error.generic,
                    detail: "chunk \(index) request failed: \(error.localizedDescription)"
                )
            }
        })
    }

    @MainActor
    private func handleChunk(_ message: HAWatchConnectivity.ImmediateMessage, index: Int) {
        guard message.content["error"] == nil, let chunk = message.content["chunkData"] as? Data else {
            let phoneError = message.content["error"] as? String
            failSync(
                L10n.Watch.Sync.Error.generic,
                detail: phoneError.map { "iPhone reported on chunk \(index): \($0)" }
                    ?? "chunk \(index) reply missing chunkData"
            )
            return
        }
        syncAccumulated.append(chunk)
        let received = index + 1
        setLoadingStatus(L10n.Watch.Sync.progress(received, syncTotalChunks))
        syncProgress = Double(received) / Double(syncTotalChunks)
        if received < syncTotalChunks {
            pullChunk(index: received)
        } else {
            finishDatabaseSync()
        }
    }

    @MainActor
    private func finishDatabaseSync() {
        let data = syncAccumulated
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
        syncAccumulated = Data()
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
    func loadCache() {
        let config: WatchConfig
        do {
            config = try Current.database().read { db in try WatchConfig.fetchOne(db) } ?? WatchConfig()
        } catch {
            // A transient read failure must not blank the home screen: keep whatever config is
            // currently rendered (possibly from an earlier successful read) — the cache is only ever
            // replaced by data that actually loaded. Only alert when there's nothing on screen at all.
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
