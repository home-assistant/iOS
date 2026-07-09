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
    @Published var currentSSID: String = ""
    @Published private(set) var homeType: WatchHomeType = .undefined

    @Published var watchConfig: WatchConfig = .init()
    @Published var magicItemsInfo: [MagicItem.Info] = []
    /// Changes every time a new config is fetched, used as a `.id()` modifier on lists to force re-render.
    @Published var configVersion = UUID()
    /// Set when the watch and iPhone both changed the config since the last sync; the UI prompts the
    /// user to choose which to keep.
    @Published var pendingConflict: ConfigConflict?

    private var networkPathMonitor: NWPathMonitor?
    private let networkMonitorQueue = DispatchQueue(label: "WatchHomeNetworkPathMonitor")
    /// Registration for background (`transferUserInfo`) config responses from the phone.
    private var guaranteedObserver: HAWatchConnectivity.ObservationToken?

    /// Minimum time each `loadingStatus` value stays on screen, so rapid chunk progress doesn't blink
    /// through numbers too fast to read.
    private static let minStatusDisplay: TimeInterval = 0.4
    private var lastStatusChangeAt: Date?
    private var pendingStatusWork: DispatchWorkItem?

    /// Minimum time the sync error banner stays on screen once shown. A failed sync immediately reloads
    /// the local cache, whose completion would otherwise clear the banner within a fraction of a second —
    /// too fast to read. Keep it up long enough to be legible.
    private static let minErrorDisplay: TimeInterval = 3
    private var errorShownAt: Date?
    private var pendingErrorClearWork: DispatchWorkItem?

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
        Communicator.shared.send(HAWatchConnectivity.GuaranteedMessage(
            identifier: InteractiveImmediateMessages.watchConfig.rawValue
        ))
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
    func requestConfig() {
        homeType = .undefined
        guard Communicator.shared.currentReachability != .notReachable else {
            Current.Log.error("iPhone reachability is not immediate reachable")
            loadCache()
            // Queue a background pull so the phone answers once it's reachable again, then updates the
            // screen via the guaranteed-response reconcile — no need for the phone to be foreground.
            setLoadingStatus(L10n.Watch.Home.Sync.waiting)
            enqueueGuaranteedConfigPull()
            return
        }
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
        Communicator.shared.send(.init(
            identifier: InteractiveImmediateMessages.watchConfigUpdate.rawValue,
            content: ["config": config.encodeForWatch()],
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
            failSync(L10n.Watch.Sync.Error.connectionFailed)
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
                self?.failSync(L10n.Watch.Sync.Error.connectionFailed)
            }
        })
    }

    @MainActor
    private func handleDatabaseSyncStart(_ message: HAWatchConnectivity.ImmediateMessage) {
        guard message.content["error"] == nil,
              let transferId = message.content["transferId"] as? String,
              let totalChunks = message.content["totalChunks"] as? Int, totalChunks > 0 else {
            failSync(L10n.Watch.Sync.Error.generic)
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
                self?.failSync(L10n.Watch.Sync.Error.generic)
            }
        })
    }

    @MainActor
    private func handleChunk(_ message: HAWatchConnectivity.ImmediateMessage, index: Int) {
        guard message.content["error"] == nil, let chunk = message.content["chunkData"] as? Data else {
            failSync(L10n.Watch.Sync.Error.generic)
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
        guard let mirror = WatchDatabaseMirror.decodeForWatch(data) else {
            failSync(L10n.Watch.Sync.Error.data)
            return
        }
        do {
            try mirror.apply()
            Current.Log.info("Applied watch database mirror (\(data.count) bytes)")
            Current.clientEventStore.addEvent(.init(
                text: "Apple Watch database sync applied (\(data.count) bytes)",
                type: .database
            ))
        } catch {
            failSync(L10n.Watch.Sync.Error.data)
            return
        }
        // Reference tables are fresh — now pull the watch config and render everything from the DB.
        setLoadingStatus(L10n.Watch.Home.Sync.syncing)
        pullWatchConfig()
    }

    @MainActor
    private func failSync(_ friendlyMessage: String) {
        resetSyncState()
        Current.Log.error("Watch database sync failed: \(friendlyMessage)")
        Current.clientEventStore.addEvent(.init(
            text: "Apple Watch database sync failed: \(friendlyMessage)",
            type: .database
        ))
        presentError(friendlyMessage)
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
        // A brand-new sync attempt supersedes any previous error, so drop it right away.
        pendingErrorClearWork?.cancel()
        pendingErrorClearWork = nil
        errorMessage = ""
        showError = false
        errorShownAt = nil
    }

    /// Show the sync error banner, cancelling any pending auto-dismiss and stamping when it appeared.
    /// Must be called on the main thread (all call sites are).
    private func presentError(_ message: String) {
        pendingErrorClearWork?.cancel()
        pendingErrorClearWork = nil
        errorMessage = message
        showError = true
        errorShownAt = Current.date()
    }

    /// Hide the sync error banner, but never before it has been on screen for `minErrorDisplay`, so the
    /// cache reload that follows a failed sync can't blink the message away before it can be read.
    /// Must be called on the main thread (all call sites are).
    private func dismissError() {
        guard showError else {
            pendingErrorClearWork?.cancel()
            pendingErrorClearWork = nil
            errorMessage = ""
            errorShownAt = nil
            return
        }

        let elapsed = errorShownAt.map { Current.date().timeIntervalSince($0) } ?? .greatestFiniteMagnitude
        if elapsed >= Self.minErrorDisplay {
            pendingErrorClearWork?.cancel()
            pendingErrorClearWork = nil
            errorMessage = ""
            showError = false
            errorShownAt = nil
            return
        }

        // Keep it up for the remainder of the minimum display window, coalescing repeated requests.
        pendingErrorClearWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            errorMessage = ""
            showError = false
            errorShownAt = nil
            pendingErrorClearWork = nil
        }
        pendingErrorClearWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (Self.minErrorDisplay - elapsed), execute: work)
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
            Current.Log.error("Failed to fetch watch config from database, error: \(error.localizedDescription)")
            displayError(message: L10n.Watch.Config.Cache.Error.message)
            updateConfig(config: .init(), magicItemsInfo: [])
            updateLoading(isLoading: false)
            return
        }

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
                self.updateLoading(isLoading: false)
            }
        }
    }

    private func updateConfig(config: WatchConfig, magicItemsInfo: [MagicItem.Info]) {
        DispatchQueue.main.async { [weak self] in
            self?.watchConfig = config
            self?.magicItemsInfo = magicItemsInfo
            self?.configVersion = UUID()

            if config.assist.showAssist,
               config.assist.serverId != nil,
               config.assist.pipelineId != nil {
                self?.showAssist = true
            } else {
                self?.showAssist = false
            }
        }
    }

    private func updateLoading(isLoading: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = isLoading
            if !isLoading {
                // Loading is over — cancel any pending throttled status update and clear immediately.
                self?.pendingStatusWork?.cancel()
                self?.pendingStatusWork = nil
                self?.loadingStatus = nil
                self?.syncProgress = nil
            }
        }
    }

    private func displayError(message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.presentError(message)
        }
    }

    private func resetError() {
        DispatchQueue.main.async { [weak self] in
            self?.dismissError()
        }
    }
}
