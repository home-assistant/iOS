import Combine
import Foundation
import Shared

final class WatchSettingsViewModel: ObservableObject {
    @Published private(set) var servers: [Server] = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var assistPipelineTitle = L10n.Watch.Config.Assist.selectPipeline
    /// The Wi-Fi network the watch is currently on, fetched on demand when settings (re)loads.
    /// Empty when unavailable (e.g. on LTE), which hides the row.
    @Published private(set) var currentSSID = ""
    /// The home-screen layout (list vs grid). Mirrors the iPhone watch-configuration editor so the user
    /// can switch it directly on the watch. Edits persist locally first and sync to the phone.
    @Published var layout: WatchLayout = WatchConfig().resolvedLayout
    /// Server ids that currently resolve NO usable URL from the watch (typically internal-only
    /// servers off a verifiable home network). Their rows show a "Needs attention" warning:
    /// while in this state the server's data doesn't sync and its complications don't update.
    @Published private(set) var serversNeedingAttention: Set<String> = []

    init() {
        Current.servers.add(observer: self)
        reload()
    }

    func reload() {
        let all = Current.servers.all
        let updatedAt = WatchUserDefaults.shared.date(for: .serversUpdatedAt)
        let assistPipelineTitle = Self.assistPipelineTitle()
        let layout = (((try? WatchConfig.config()) ?? nil) ?? WatchConfig()).resolvedLayout
        DispatchQueue.main.async { [weak self] in
            self?.servers = all
            self?.lastUpdated = updatedAt
            self?.assistPipelineTitle = assistPipelineTitle
            self?.layout = layout
        }
        Task { @MainActor [weak self] in
            // `currentWiFiSSID()` fetches fresh network information itself.
            self?.currentSSID = await Current.connectivity.currentWiFiSSID() ?? ""
        }
        Task { [weak self] in
            var needingAttention = WatchUserDefaults.shared.directSyncNoReachableURLServerIds
            for server in all {
                let serverId = server.identifier.rawValue
                if await server.activeURL() == nil {
                    needingAttention.insert(serverId)
                }
            }
            await MainActor.run { [weak self, needingAttention] in
                self?.serversNeedingAttention = needingAttention
            }
        }
    }

    /// Change the home-screen layout. Follows the same offline-first flow as the Assist editor: persist
    /// the edit locally so it survives without the phone nearby, then push it to the phone (source of
    /// truth) when reachable; otherwise it syncs on the next reload.
    func updateLayout(_ newValue: WatchLayout) {
        layout = newValue
        var config = ((try? WatchConfig.config()) ?? nil) ?? WatchConfig()
        guard config.layout != newValue else { return }
        config.layout = newValue
        config.stampModified()
        persistLocally(config)
        NotificationCenter.default.post(name: .watchConfigDidChange, object: nil)
        syncToPhone(config)
    }

    private func persistLocally(_ config: WatchConfig) {
        do {
            try Current.database().write { db in
                var config = config
                if config.id != WatchConfig.watchConfigId {
                    try WatchConfig.deleteAll(db)
                    config.id = WatchConfig.watchConfigId
                }
                try config.insert(db, onConflict: .replace)
            }
        } catch {
            Current.Log.error("Failed to persist watch layout locally on watch: \(error.localizedDescription)")
        }
    }

    private func syncToPhone(_ config: WatchConfig) {
        guard Communicator.shared.currentReachability == .immediatelyReachable else { return }
        let configData: Data
        do {
            configData = try config.encodeForWatch()
        } catch {
            // The local copy is already saved; it'll sync on the next reload.
            Current.Log.error("Failed to encode watch layout for sync: \(error.localizedDescription)")
            return
        }
        Communicator.shared.send(.init(
            identifier: InteractiveImmediateMessages.watchConfigUpdate.rawValue,
            content: ["config": configData],
            reply: { [weak self] message in
                DispatchQueue.main.async { self?.handleLayoutSyncResponse(message) }
            }
        ), errorHandler: { error in
            // The local copy is already saved; it'll sync on the next reload.
            Current.Log.error("Failed to sync watch layout to phone: \(error.localizedDescription)")
        })
    }

    private func handleLayoutSyncResponse(_ message: HAWatchConnectivity.ImmediateMessage) {
        guard message.identifier == InteractiveImmediateResponses.watchConfigResponse.rawValue,
              let configData = message.content["config"] as? Data,
              let config = WatchConfig.decodeForWatch(configData) else {
            // The local copy is already saved; it'll sync on the next reload.
            return
        }
        persistLocally(config)
        // The phone accepted our push, so this is now the synced baseline.
        WatchUserDefaults.shared.lastSyncedModified = config.lastModified
        NotificationCenter.default.post(name: .watchConfigDidChange, object: nil)
    }

    /// Wipe all data stored locally on this Watch: the offline GRDB database (mirrored servers,
    /// entities, watch config, etc.) and the cached magic-items JSON. The iPhone and servers are
    /// untouched; a refresh from the Home screen re-syncs everything. Returns `false` if anything
    /// failed so the UI can surface an error.
    @discardableResult
    func deleteLocalData() -> Bool {
        var success = true

        do {
            try Current.database().eraseAllData()
        } catch {
            Current.Log.error("Failed to erase watch local database: \(error.localizedDescription)")
            success = false
        }

        let cacheURL = AppConstants.watchMagicItemsInfo
        if FileManager.default.fileExists(atPath: cacheURL.path) {
            do {
                try FileManager.default.removeItem(at: cacheURL)
            } catch {
                Current.Log.error("Failed to delete watch cached JSON: \(error.localizedDescription)")
                success = false
            }
        }

        reload()
        return success
    }

    private static func assistPipelineTitle() -> String {
        guard let config = try? WatchConfig.config(),
              config.assist.showAssist,
              let pipelineId = config.assist.pipelineId else {
            return L10n.Watch.Config.Assist.selectPipeline
        }
        if pipelineId.isEmpty {
            return L10n.Watch.Config.Assist.preferred
        }
        return WatchUserDefaults.shared.assistPipelineName ?? pipelineId
    }
}

extension WatchSettingsViewModel: ServerObserver {
    func serversDidChange(_ serverManager: ServerManager) {
        reload()
    }
}
