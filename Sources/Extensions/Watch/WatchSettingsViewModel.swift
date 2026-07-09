import Combine
import Foundation
import Shared

final class WatchSettingsViewModel: ObservableObject {
    @Published private(set) var servers: [Server] = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var assistPipelineTitle = L10n.Watch.Config.Assist.selectPipeline

    init() {
        Current.servers.add(observer: self)
        reload()
    }

    func reload() {
        let all = Current.servers.all
        let updatedAt = WatchUserDefaults.shared.date(for: .serversUpdatedAt)
        let assistPipelineTitle = Self.assistPipelineTitle()
        DispatchQueue.main.async { [weak self] in
            self?.servers = all
            self?.lastUpdated = updatedAt
            self?.assistPipelineTitle = assistPipelineTitle
        }
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
